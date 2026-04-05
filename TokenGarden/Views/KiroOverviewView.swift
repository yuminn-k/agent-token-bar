import SwiftUI
import SwiftData

struct KiroOverviewView: View {
    @EnvironmentObject var kiroUsageService: KiroUsageService
    @Query(sort: \KiroDailyUsage.date) private var dailyUsages: [KiroDailyUsage]
    @State private var selectedDate: Date?

    private var todayCredits: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyUsages.first(where: { $0.date == today })?.creditsUsed ?? 0
    }

    private var monthCredits: Double {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: Date())
        let monthStart = calendar.date(from: comps)!
        return dailyUsages.filter { $0.date >= monthStart }.reduce(0) { $0 + $1.creditsUsed }
    }

    private var heatmapData: [(date: Date, tokens: Int)] {
        dailyUsages.map { (date: $0.date, tokens: Int(($0.creditsUsed * 100).rounded())) }
    }

    private var selectedDayCredits: Double? {
        guard let selectedDate else { return nil }
        let day = Calendar.current.startOfDay(for: selectedDate)
        return dailyUsages.first(where: { $0.date == day })?.creditsUsed ?? 0
    }

    var body: some View {
        switch kiroUsageService.status {
        case .notInstalled where kiroUsageService.currentSummary == nil:
            EmptyStateView(reason: .kiroNotInstalled)
                .frame(minHeight: 220)
        case .notLoggedIn where kiroUsageService.currentSummary == nil:
            EmptyStateView(reason: .kiroNotLoggedIn)
                .frame(minHeight: 220)
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard
                        .padding(.top, 8)

                    PanelCard(
                        title: "Credit Totals",
                        subtitle: "Rolling usage snapshots from Kiro CLI",
                        systemImage: "creditcard.fill"
                    ) {
                        HStack(spacing: 8) {
                            MetricTile(label: "Today", value: TokenFormatter.formatCredits(todayCredits), note: "Accumulated locally")
                            MetricTile(label: "This Month", value: TokenFormatter.formatCredits(monthCredits), note: "Month to date")
                        }
                    }

                    if dailyUsages.isEmpty {
                        EmptyStateView(reason: .noKiroData)
                            .frame(minHeight: 180)
                    } else {
                        PanelCard(
                            title: "Kiro Heatmap",
                            subtitle: "Daily credits since local tracking started",
                            systemImage: "calendar"
                        ) {
                            HeatmapView(
                                dailyUsages: heatmapData,
                                selectedDate: $selectedDate,
                                valueFormatter: { TokenFormatter.formatCredits(Double($0) / 100.0) }
                            )

                            HStack {
                                Text(selectedDateLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(TokenFormatter.formatCredits(selectedDayCredits ?? todayCredits))
                                    .font(.caption.monospacedDigit())
                                    .fontWeight(.medium)
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }

    private var selectedDateLabel: String {
        guard let selectedDate else { return "Today" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: selectedDate)
    }

    private var summaryCard: some View {
        PanelCard(
            title: "Kiro Usage",
            subtitle: "Live credit usage for the current billing cycle",
            systemImage: "terminal.fill",
            trailing: AnyView(
                Button {
                    kiroUsageService.refresh()
                } label: {
                    if kiroUsageService.status == .refreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            )
        ) {
            if let summary = kiroUsageService.currentSummary {
                HStack(spacing: 8) {
                    MetricTile(
                        label: summary.planName ?? "Plan",
                        value: TokenFormatter.formatCredits(summary.usedCredits),
                        note: "Used this cycle"
                    )
                    if let remaining = summary.remainingCredits {
                        MetricTile(label: "Remaining", value: TokenFormatter.formatCredits(remaining), note: "Before reset")
                    } else if let total = summary.totalCredits {
                        MetricTile(label: "Allowance", value: TokenFormatter.formatCredits(total), note: "Cycle total")
                    }
                }

                if let total = summary.totalCredits {
                    let progress = total > 0 ? min(max(summary.usedCredits / total, 0), 1) : 0
                    ProgressView(value: progress)
                        .tint(progress >= 0.8 ? .orange : .accentColor)
                }

                if let resetAt = summary.resetAt {
                    Text("Resets \(Self.resetFormatter.string(from: resetAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusDescription: String {
        switch kiroUsageService.status {
        case .idle:
            return "Ready to refresh Kiro usage."
        case .refreshing:
            return "Refreshing current credits…"
        case .ready:
            return "Latest Kiro usage loaded."
        case .notInstalled:
            return "Kiro CLI is not installed."
        case .notLoggedIn:
            return "Kiro CLI is installed, but not logged in."
        case .failed(let message):
            return message.isEmpty ? "Failed to refresh Kiro usage." : message
        }
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
