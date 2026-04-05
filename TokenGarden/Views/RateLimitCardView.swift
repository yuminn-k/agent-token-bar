import SwiftUI

struct RateLimitCardView: View {
    let state: CodexRateLimitState

    var body: some View {
        PanelCard(
            title: "Codex Rate Limits",
            subtitle: "Current 5-hour and 7-day allowance usage",
            systemImage: "gauge.with.dots.needle.67percent",
            trailing: AnyView(
                Group {
                    if let planType = state.planType {
                        Text(planType.capitalized)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
            )
        ) {
            if let latestTurnTokens = state.latestTurnTokens {
                MetricTile(label: "Last Turn", value: TokenFormatter.format(latestTurnTokens), note: "Most recent response size")
            }

            quotaRow(label: "5h", value: state.fiveHourUsedPercent, resetAt: state.fiveHourResetAt)
            quotaRow(label: "7d", value: state.sevenDayUsedPercent, resetAt: state.sevenDayResetAt)
        }
    }

    private func quotaRow(label: String, value: Double, resetAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption.monospacedDigit())
                if let resetAt {
                    Text("· resets \(Self.resetFormatter.string(from: resetAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(value >= 0.8 ? .orange : .accentColor)
        }
    }

    private static let resetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "M/d HH:mm"
        return formatter
    }()
}
