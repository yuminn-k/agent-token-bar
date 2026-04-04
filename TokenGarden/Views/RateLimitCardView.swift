import SwiftUI

struct RateLimitCardView: View {
    let state: CodexRateLimitState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Codex Limits", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let planType = state.planType {
                    Text(planType.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: Capsule())
                }
            }

            if let latestTurnTokens = state.latestTurnTokens {
                HStack {
                    Text("Last Turn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(TokenFormatter.format(latestTurnTokens))
                        .font(.caption.monospacedDigit())
                }
            }

            quotaRow(
                label: "5h",
                value: state.fiveHourUsedPercent,
                resetAt: state.fiveHourResetAt
            )

            quotaRow(
                label: "7d",
                value: state.sevenDayUsedPercent,
                resetAt: state.sevenDayResetAt
            )
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func quotaRow(label: String, value: Double, resetAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
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
