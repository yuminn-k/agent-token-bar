import Foundation
import SwiftUI

struct KiroUsageSummary: Sendable {
    let timestamp: Date
    let usedCredits: Double
    let remainingCredits: Double?
    let totalCredits: Double?
    let planName: String?
    let resetAt: Date?
    let rawOutput: String
}

@MainActor
final class KiroUsageService: ObservableObject {
    enum Status: Equatable {
        case idle
        case refreshing
        case ready
        case notInstalled
        case notLoggedIn
        case failed(String)
    }

    @Published var status: Status = .idle
    @Published var currentSummary: KiroUsageSummary?
    @Published var lastUpdatedAt: Date?

    private let dataStore: TokenDataStore
    private var timer: Timer?

    @AppStorage("kiroBinaryPath") private var kiroBinaryPath = "kiro-cli"
    @AppStorage("kiroRefreshIntervalMinutes") private var refreshIntervalMinutes = 15

    init(dataStore: TokenDataStore) {
        self.dataStore = dataStore
    }

    func start() {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: max(60, Double(refreshIntervalMinutes) * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        status = .refreshing
        let binary = kiroBinaryPath
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let availability = Self.checkAvailability(binary: binary)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    switch availability {
                    case .notInstalled:
                        self.status = .notInstalled
                    case .notLoggedIn:
                        self.status = .notLoggedIn
                    case .available:
                        self.fetchUsage(binary: binary)
                    case .failed(let message):
                        self.status = .failed(message)
                    }
                }
            }
        }
    }

    private func fetchUsage(binary: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let output = Self.run(binary: binary, arguments: ["chat", "--no-interactive", "/usage"])
            DispatchQueue.main.async {
                guard let self else { return }
                MainActor.assumeIsolated {
                    if let summary = Self.parseUsageOutput(output.stdout), output.status == 0 {
                        self.currentSummary = summary
                        self.lastUpdatedAt = summary.timestamp
                        self.status = .ready
                        self.dataStore.recordKiroSnapshot(summary)
                    } else if output.stdout.localizedCaseInsensitiveContains("Not logged in") || output.stderr.localizedCaseInsensitiveContains("Not logged in") {
                        self.status = .notLoggedIn
                    } else {
                        let message = output.stderr.isEmpty ? output.stdout : output.stderr
                        self.status = .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }

    private enum AvailabilityCheck {
        case available
        case notInstalled
        case notLoggedIn
        case failed(String)
    }

    private static func checkAvailability(binary: String) -> AvailabilityCheck {
        let which = run(binary: "/usr/bin/env", arguments: ["which", binary])
        if which.status != 0 || which.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .notInstalled
        }

        let whoami = run(binary: binary, arguments: ["whoami"])
        let normalized = [whoami.stdout, whoami.stderr].joined(separator: "\n")
        if normalized.localizedCaseInsensitiveContains("Not logged in") {
            return .notLoggedIn
        }
        if whoami.status != 0 {
            return .failed(normalized)
        }
        return .available
    }

    static func parseUsageOutput(_ output: String) -> KiroUsageSummary? {
        let cleaned = stripANSI(output)
        let compact = cleaned.replacingOccurrences(of: "\u{00A0}", with: " ")

        let used = firstMatch(in: compact, patterns: [
            #"(?i)(?:used|consumed|spent)[^\d]*(\d[\d,]*(?:\.\d+)?)\s*credits"#,
            #"(?i)(\d[\d,]*(?:\.\d+)?)\s*(?:/|of)\s*(\d[\d,]*(?:\.\d+)?)\s*credits"#
        ])
        let total = secondMatch(in: compact, patterns: [
            #"(?i)(\d[\d,]*(?:\.\d+)?)\s*(?:/|of)\s*(\d[\d,]*(?:\.\d+)?)\s*credits"#,
            #"(?i)(?:included|total|limit)[^\d]*(\d[\d,]*(?:\.\d+)?)\s*credits"#
        ])
        let remaining = firstMatch(in: compact, patterns: [
            #"(?i)(?:remaining|left|available)[^\d]*(\d[\d,]*(?:\.\d+)?)\s*credits"#
        ])

        let normalizedUsed = used ?? {
            if let total, let remaining {
                return max(0, total - remaining)
            }
            return nil
        }()

        guard let usedCredits = normalizedUsed else { return nil }

        let planName = planMatch(in: compact)
        let resetAt = dateMatch(in: compact)
        let resolvedTotal = total ?? (remaining != nil ? usedCredits + (remaining ?? 0) : nil)

        return KiroUsageSummary(
            timestamp: Date(),
            usedCredits: usedCredits,
            remainingCredits: remaining,
            totalCredits: resolvedTotal,
            planName: planName,
            resetAt: resetAt,
            rawOutput: compact
        )
    }

    private static func run(binary: String, arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary == "kiro-cli" ? "/usr/bin/env" : binary)
        process.arguments = binary == "kiro-cli" ? [binary] + arguments : arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return (1, "", error.localizedDescription)
        }
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }

    private static func stripANSI(_ string: String) -> String {
        string.replacingOccurrences(of: #"\u001B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsrange), match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { continue }
            return Double(text[range].replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private static func secondMatch(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsrange), match.numberOfRanges > 2,
                  let range = Range(match.range(at: 2), in: text) else { continue }
            return Double(text[range].replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    private static func planMatch(in text: String) -> String? {
        let candidates = ["Power", "Pro+", "Pro", "Free"]
        return candidates.first { text.localizedCaseInsensitiveContains($0) }
    }

    private static func dateMatch(in text: String) -> Date? {
        let patterns = [
            #"(20\d{2}-\d{2}-\d{2})"#,
            #"(20\d{2}/\d{2}/\d{2})"#
        ]
        let formatters: [(String) -> Date?] = [
            { text in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: text)
            },
            { text in
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy/MM/dd"
                return formatter.date(from: text)
            }
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, range: nsrange), match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range])
            for formatter in formatters {
                if let date = formatter(value) {
                    return date
                }
            }
        }
        return nil
    }
}
