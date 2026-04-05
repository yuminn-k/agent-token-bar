import SwiftUI
import SwiftData

struct CodexOverviewView: View {
    @EnvironmentObject var codexStatusStore: CodexStatusStore
    @Query(sort: \DailyUsage.date) private var allUsages: [DailyUsage]
    @Query private var allHourlyUsages: [HourlyUsage]
    @State private var selectedDate: Date?

    private var todayUsage: DailyUsage? {
        let today = Calendar.current.startOfDay(for: Date())
        return allUsages.first { $0.date == today }
    }

    private var weekTokens: Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let weekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
        return allUsages.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.totalTokens }
    }

    private var monthTokens: Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: comps)!
        return allUsages.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.totalTokens }
    }

    private var heatmapData: [(date: Date, tokens: Int)] {
        allUsages.map { (date: $0.date, tokens: $0.totalTokens) }
    }

    private var activeHourlyTokens: [Int] {
        let cal = Calendar.current
        let targetDay = cal.startOfDay(for: selectedDate ?? Date())
        let dayEntries = allHourlyUsages.filter { $0.date == targetDay }
        var buckets = Array(repeating: 0, count: 24)
        for entry in dayEntries where entry.hour >= 0 && entry.hour < 24 {
            buckets[entry.hour] += entry.tokens
        }
        return buckets
    }

    private func projectsForUsages(_ usages: [DailyUsage]) -> [(name: String, tokens: Int)] {
        var totals: [String: Int] = [:]
        for usage in usages {
            for project in usage.projectBreakdowns {
                totals[project.projectName, default: 0] += project.tokens
            }
        }
        return totals.map { (name: $0.key, tokens: $0.value) }
    }

    private var todayProjects: [(name: String, tokens: Int)] {
        let today = Calendar.current.startOfDay(for: Date())
        return projectsForUsages(allUsages.filter { $0.date == today })
    }

    private var weekProjects: [(name: String, tokens: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let weekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date!
        return projectsForUsages(allUsages.filter { $0.date >= weekStart })
    }

    private var monthProjects: [(name: String, tokens: Int)] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: comps)!
        return projectsForUsages(allUsages.filter { $0.date >= monthStart })
    }

    private var selectedDayProjects: [(name: String, tokens: Int)]? {
        guard let date = selectedDate else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        let usages = allUsages.filter { $0.date == day }
        guard !usages.isEmpty else { return [] }
        return projectsForUsages(usages)
    }

    private var selectedDayLabel: String? {
        guard let date = selectedDate else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: date)
    }

    private var emptyStateReason: EmptyStateReason? {
        let path = NSString(string: "~/.codex/sessions").expandingTildeInPath
        if !FileManager.default.fileExists(atPath: path) {
            return .noCodexLogs
        }
        if !FileManager.default.isReadableFile(atPath: path) {
            return .noPermission(path)
        }
        if allUsages.isEmpty {
            return .noCodexData
        }
        return nil
    }

    var body: some View {
        if let reason = emptyStateReason {
            EmptyStateView(reason: reason)
                .frame(minHeight: 220)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    StatsView(
                        todayTokens: todayUsage?.totalTokens ?? 0,
                        weekTokens: weekTokens,
                        monthTokens: monthTokens
                    )
                    .padding(.top, 8)

                    PanelCard(
                        title: "Activity Heatmap",
                        subtitle: "Tap a day to inspect exact tokens and project mix",
                        systemImage: "calendar"
                    ) {
                        HeatmapView(dailyUsages: heatmapData, selectedDate: $selectedDate)
                        if let date = selectedDate,
                           let usage = allUsages.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                            HStack {
                                Text(selectedDayLabel ?? "Selected day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(TokenFormatter.format(usage.totalTokens))
                                    .font(.caption.monospacedDigit())
                                    .fontWeight(.medium)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    if let state = codexStatusStore.latestRateLimit {
                        RateLimitCardView(state: state)
                    }

                    HourlyChartView(
                        hourlyTokens: activeHourlyTokens,
                        isToday: selectedDate == nil || Calendar.current.isDateInToday(selectedDate!)
                    )

                    ProjectListView(
                        todayProjects: todayProjects,
                        weekProjects: weekProjects,
                        monthProjects: monthProjects,
                        selectedDayProjects: selectedDayProjects,
                        selectedDayLabel: selectedDayLabel
                    )

                    SessionListView()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }
}
