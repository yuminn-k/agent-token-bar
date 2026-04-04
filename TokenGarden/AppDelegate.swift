import AppKit
import SwiftData
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var menuBarController: MenuBarController!
    private var logWatcher: LogWatcher!
    private var dataStore: TokenDataStore!
    private var modelContainer: ModelContainer!
    private var animationTimer: Timer!
    private var updateChecker: UpdateChecker!
    private var codexStatusStore: CodexStatusStore!
    private var kiroUsageService: KiroUsageService!
    private var codexParser: CodexSessionLogParser!

    private nonisolated(unsafe) let refreshLock = NSLock()
    private nonisolated(unsafe) var pendingActiveProjects: Set<String>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.agentgarden"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if running.count > 1 {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let schema = Schema([
            DailyUsage.self,
            ProjectUsage.self,
            SessionUsage.self,
            HourlyUsage.self,
            KiroDailyUsage.self,
            KiroUsageSnapshot.self,
        ])
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentGarden", isDirectory: true)
            .appendingPathComponent("AgentGarden.store")
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let config = ModelConfiguration("AgentGarden", schema: schema, url: storeURL)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            let storeDir = storeURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: storeDir)
            try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
            UserDefaults.standard.removeObject(forKey: "AgentGardenLogWatcherOffsets")
            modelContainer = try! ModelContainer(for: schema, configurations: [config])
        }

        dataStore = TokenDataStore(modelContainer: modelContainer)
        codexStatusStore = CodexStatusStore()
        kiroUsageService = KiroUsageService(dataStore: dataStore)
        codexParser = CodexSessionLogParser()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = AnimationFrames.idleImage()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        menuBarController = MenuBarController(statusItem: statusItem, initialTodayTokens: 0, initialHourlyBuckets: [0, 0, 0])

        animationTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.menuBarController.tick()
                self?.applyPendingRefreshIfNeeded()
            }
        }
        RunLoop.main.add(animationTimer, forMode: .common)

        updateChecker = UpdateChecker()
        updateChecker.check()

        popover = NSPopover()
        popover.behavior = .transient
        let popoverView = PopoverView()
            .environmentObject(menuBarController)
            .environmentObject(updateChecker)
            .environmentObject(codexStatusStore)
            .environmentObject(kiroUsageService)
            .modelContainer(modelContainer)
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController

        logWatcher = LogWatcher(watchPaths: codexParser.watchPaths) { [weak self] path, line in
            self?.handleCodexLine(path: path, line: line)
        }
        logWatcher.backfill { [weak self] in
            self?.dataStore.flush()
            self?.triggerRefresh()
            self?.reloadMenuBar()
        }
        logWatcher.start()

        startSessionRefreshLoop()
        kiroUsageService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationTimer?.invalidate()
        logWatcher?.stop()
        kiroUsageService?.stop()
        dataStore?.flush()
    }

    private func handleCodexLine(path: String, line: String) {
        for record in codexParser.parse(line: line, filePath: path) {
            switch record {
            case .usage(let event):
                dataStore.record(event)
                menuBarController.onTokenEvent(event)
            case .rateLimit(let state):
                codexStatusStore.update(state)
            }
        }
    }

    private func reloadMenuBar() {
        let todayTokens = dataStore.fetchDailyUsages(
            from: Calendar.current.startOfDay(for: Date()),
            to: Date()
        ).first?.totalTokens ?? 0
        let hourlyBuckets = dataStore.fetchHourlyBuckets()
        menuBarController.reloadData(todayTokens: todayTokens, hourlyBuckets: hourlyBuckets)
    }

    private func triggerRefresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let projects = TokenDataStore.getActiveCodexProjects()
            self?.refreshLock.lock()
            self?.pendingActiveProjects = projects
            self?.refreshLock.unlock()
        }
    }

    private func startSessionRefreshLoop() {
        Thread.detachNewThread { [weak self] in
            while true {
                let projects = TokenDataStore.getActiveCodexProjects()
                self?.refreshLock.lock()
                self?.pendingActiveProjects = projects
                self?.refreshLock.unlock()
                Thread.sleep(forTimeInterval: 30)
            }
        }
    }

    private func applyPendingRefreshIfNeeded() {
        refreshLock.lock()
        let projects = pendingActiveProjects
        pendingActiveProjects = nil
        refreshLock.unlock()

        if let projects {
            dataStore.applyActiveStatus(activeProjects: projects)
        }
    }

    @objc func togglePopover() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit Agent Garden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.statusItem.menu = nil
            }
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
