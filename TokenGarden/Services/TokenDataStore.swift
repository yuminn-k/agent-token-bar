import Foundation
import SwiftData

@MainActor
class TokenDataStore: ObservableObject {
    private let modelContext: ModelContext
    private var pendingSaveCount = 0
    private static let saveInterval = 10

    init(modelContainer: ModelContainer) {
        self.modelContext = modelContainer.mainContext
    }

    func record(_ event: TokenEvent) {
        let day = Calendar.current.startOfDay(for: event.timestamp)
        let daily = fetchOrCreateDailyUsage(for: day)

        daily.totalTokens += event.totalTokens
        daily.inputTokens += event.inputTokens
        daily.outputTokens += event.outputTokens
        daily.cachedInputTokens += event.cachedInputTokens
        daily.reasoningOutputTokens += event.reasoningOutputTokens

        let hour = Calendar.current.component(.hour, from: event.timestamp)
        let hourlyDescriptor = FetchDescriptor<HourlyUsage>(
            predicate: #Predicate { $0.date == day && $0.hour == hour }
        )
        if let existing = try? modelContext.fetch(hourlyDescriptor).first {
            existing.tokens += event.totalTokens
        } else {
            modelContext.insert(HourlyUsage(date: day, hour: hour, tokens: event.totalTokens))
        }

        if let projectName = event.projectName {
            if let existing = daily.projectBreakdowns.first(where: { $0.projectName == projectName }) {
                existing.tokens += event.totalTokens
            } else {
                let projectUsage = ProjectUsage(projectName: projectName, tokens: event.totalTokens, model: event.model)
                projectUsage.dailyUsage = daily
                daily.projectBreakdowns.append(projectUsage)
            }
        }

        if let sessionId = event.sessionId {
            let sessionDescriptor = FetchDescriptor<SessionUsage>(
                predicate: #Predicate { $0.sessionId == sessionId }
            )
            if let session = try? modelContext.fetch(sessionDescriptor).first {
                session.totalTokens += event.totalTokens
                session.lastTime = event.timestamp
            } else {
                let session = SessionUsage(
                    sessionId: sessionId,
                    projectName: event.projectName ?? "Unknown",
                    startTime: event.timestamp
                )
                session.totalTokens = event.totalTokens
                session.lastTime = event.timestamp
                modelContext.insert(session)
            }
        }

        pendingSaveCount += 1
        if pendingSaveCount >= Self.saveInterval {
            flush()
        }
    }

    func applyActiveStatus(activeProjects: Set<String>) {
        let descriptor = FetchDescriptor<SessionUsage>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        for session in sessions {
            session.isActive = false
            if activeProjects.contains(session.projectName) {
                let projectSessions = sessions
                    .filter { $0.projectName == session.projectName }
                    .sorted { $0.lastTime > $1.lastTime }
                if projectSessions.first?.sessionId == session.sessionId {
                    session.isActive = true
                }
            }
        }
        try? modelContext.save()
    }

    func recordKiroSnapshot(_ summary: KiroUsageSummary) {
        let descriptor = FetchDescriptor<KiroUsageSnapshot>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let previous = try? modelContext.fetch(descriptor).first

        let snapshot = KiroUsageSnapshot(
            timestamp: summary.timestamp,
            usedCredits: summary.usedCredits,
            remainingCredits: summary.remainingCredits,
            totalCredits: summary.totalCredits,
            planName: summary.planName,
            resetAt: summary.resetAt,
            rawOutput: summary.rawOutput
        )
        modelContext.insert(snapshot)

        let delta = kiroDelta(previous: previous, current: snapshot)
        if delta > 0.0001 {
            let day = Calendar.current.startOfDay(for: summary.timestamp)
            let dailyDescriptor = FetchDescriptor<KiroDailyUsage>(predicate: #Predicate { $0.date == day })
            if let existing = try? modelContext.fetch(dailyDescriptor).first {
                existing.creditsUsed += delta
            } else {
                modelContext.insert(KiroDailyUsage(date: day, creditsUsed: delta))
            }
        }

        try? modelContext.save()
    }

    private func kiroDelta(previous: KiroUsageSnapshot?, current: KiroUsageSnapshot) -> Double {
        guard let previous else { return 0 }
        if let currentReset = current.resetAt,
           let previousReset = previous.resetAt,
           currentReset != previousReset,
           current.usedCredits < previous.usedCredits {
            return current.usedCredits
        }
        if current.usedCredits < previous.usedCredits {
            return 0
        }
        return current.usedCredits - previous.usedCredits
    }

    func flush() {
        if pendingSaveCount > 0 {
            try? modelContext.save()
            pendingSaveCount = 0
        }
    }

    func fetchDailyUsages(from startDate: Date, to endDate: Date) -> [DailyUsage] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let descriptor = FetchDescriptor<DailyUsage>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchKiroDailyUsages(from startDate: Date, to endDate: Date) -> [KiroDailyUsage] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let descriptor = FetchDescriptor<KiroDailyUsage>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchHourlyBuckets() -> [Int] {
        let cal = Calendar.current
        let now = Date()
        let currentHour = cal.component(.hour, from: now)
        let today = cal.startOfDay(for: now)

        var buckets = [0, 0, 0]
        for i in 0..<3 {
            let hour = currentHour - 2 + i
            guard let hourStart = cal.date(bySettingHour: hour, minute: 0, second: 0, of: today),
                  let hourEnd = cal.date(bySettingHour: hour, minute: 59, second: 59, of: today) else { continue }

            let descriptor = FetchDescriptor<SessionUsage>(
                predicate: #Predicate<SessionUsage> { session in
                    session.lastTime >= hourStart && session.startTime <= hourEnd
                }
            )
            if let sessions = try? modelContext.fetch(descriptor) {
                buckets[i] = sessions.reduce(0) { $0 + $1.totalTokens }
            }
        }
        return buckets
    }

    nonisolated static func getActiveCodexProjects() -> Set<String> {
        let psPipe = Pipe()
        let psProc = Process()
        psProc.executableURL = URL(fileURLWithPath: "/bin/ps")
        psProc.arguments = ["-eo", "pid,comm"]
        psProc.standardOutput = psPipe
        psProc.standardError = FileHandle.nullDevice

        do { try psProc.run() } catch { return [] }
        let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
        psProc.waitUntilExit()
        guard let psOutput = String(data: psData, encoding: .utf8) else { return [] }

        var pids: [String] = []
        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("/codex") || trimmed.contains(" codex") {
                let parts = trimmed.split(separator: " ", maxSplits: 1)
                if let pid = parts.first {
                    pids.append(String(pid))
                }
            }
        }
        guard !pids.isEmpty else { return [] }

        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-a", "-d", "cwd", "-p", pids.joined(separator: ",")]
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do { try proc.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var projects = Set<String>()
        for line in output.components(separatedBy: "\n") {
            guard line.contains("cwd") else { continue }
            let parts = line.split(separator: " ", maxSplits: 8)
            if parts.count >= 9 {
                let path = String(parts[8])
                projects.insert(URL(fileURLWithPath: path).lastPathComponent)
            }
        }
        return projects
    }

    private func fetchOrCreateDailyUsage(for day: Date) -> DailyUsage {
        let descriptor = FetchDescriptor<DailyUsage>(predicate: #Predicate { $0.date == day })
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let daily = DailyUsage(date: day)
        modelContext.insert(daily)
        return daily
    }
}
