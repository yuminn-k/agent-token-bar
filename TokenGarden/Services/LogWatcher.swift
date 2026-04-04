import Foundation

@MainActor
class LogWatcher {
    private let watchPaths: [String]
    private let onNewLine: @MainActor (String, String) -> Void
    private var stream: FSEventStreamRef?
    private var fileOffsets: [String: Int] = [:]
    private let offsetsKey = "AgentGardenLogWatcherOffsets"

    init(watchPaths: [String], onNewLine: @escaping @MainActor (String, String) -> Void) {
        self.watchPaths = watchPaths
        self.onNewLine = onNewLine
        loadOffsets()
    }

    func start() {
        let existingPaths = watchPaths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingPaths.isEmpty else { return }

        let pathsToWatch = existingPaths as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            LogWatcher.eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        saveOffsets()
    }

    func backfill(completion: @escaping @MainActor () -> Void = {}) {
        let currentOffsets = fileOffsets
        let paths = watchPaths.filter { FileManager.default.fileExists(atPath: $0) }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var fileLines: [(path: String, line: String)] = []
            var newOffsets: [String: Int] = [:]

            for watchPath in paths {
                if let enumerator = FileManager.default.enumerator(atPath: watchPath) {
                    while let relativePath = enumerator.nextObject() as? String {
                        let fullPath = (watchPath as NSString).appendingPathComponent(relativePath)
                        guard Self.isSupportedFile(path: fullPath), currentOffsets[fullPath] == nil else { continue }
                        Self.collectLines(from: fullPath, into: &fileLines, offsets: &newOffsets)
                    }
                } else if Self.isSupportedFile(path: watchPath) {
                    guard currentOffsets[watchPath] == nil else { continue }
                    Self.collectLines(from: watchPath, into: &fileLines, offsets: &newOffsets)
                }
            }

            DispatchQueue.main.async {
                guard let self else { return }
                MainActor.assumeIsolated {
                    for (path, offset) in newOffsets {
                        self.fileOffsets[path] = offset
                    }
                    self.saveOffsets()
                    for fileLine in fileLines {
                        self.onNewLine(fileLine.path, fileLine.line)
                    }
                    completion()
                }
            }
        }
    }

    nonisolated private static let eventCallback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
        guard let info else { return }
        let watcher = Unmanaged<LogWatcher>.fromOpaque(info).takeUnretainedValue()
        guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

        let filteredPaths = paths.filter(Self.isSupportedFile(path:))
        Task { @MainActor in
            for path in filteredPaths {
                watcher.processFile(at: path)
            }
        }
    }

    private func processFile(at path: String) {
        guard FileManager.default.fileExists(atPath: path),
              let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { handle.closeFile() }

        let fileSize = Int(handle.seekToEndOfFile())
        let offset = fileOffsets[path] ?? 0

        if offset > fileSize {
            fileOffsets[path] = 0
            handle.seek(toFileOffset: 0)
        } else {
            handle.seek(toFileOffset: UInt64(offset))
        }

        let data = handle.readDataToEndOfFile()
        fileOffsets[path] = Int(handle.offsetInFile)
        saveOffsets()

        guard let content = String(data: data, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            onNewLine(path, line)
        }
    }

    private func loadOffsets() {
        fileOffsets = UserDefaults.standard.dictionary(forKey: offsetsKey) as? [String: Int] ?? [:]
    }

    private func saveOffsets() {
        UserDefaults.standard.set(fileOffsets, forKey: offsetsKey)
    }

    private static func isSupportedFile(path: String) -> Bool {
        if path.hasSuffix(".jsonl") { return true }
        if path.hasSuffix(".log") { return true }
        return false
    }

    private static func collectLines(
        from path: String,
        into fileLines: inout [(path: String, line: String)],
        offsets: inout [String: Int]
    ) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { handle.closeFile() }

        let data = handle.readDataToEndOfFile()
        offsets[path] = Int(handle.offsetInFile)
        guard let content = String(data: data, encoding: .utf8) else { return }
        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            fileLines.append((path: path, line: line))
        }
    }
}
