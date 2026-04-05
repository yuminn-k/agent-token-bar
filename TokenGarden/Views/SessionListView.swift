import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(
        filter: #Predicate<SessionUsage> { $0.isActive == true },
        sort: \SessionUsage.lastTime,
        order: .reverse
    ) private var activeSessions: [SessionUsage]

    var body: some View {
        PanelCard(
            title: "Active Sessions",
            subtitle: "Currently running Codex workspaces",
            systemImage: "bolt.fill",
            trailing: AnyView(
                Text("\(activeSessions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            )
        ) {
            if activeSessions.isEmpty {
                Text("No active sessions right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(activeSessions.prefix(5)), id: \.sessionId) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: SessionUsage

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var duration: String {
        let interval = Date().timeIntervalSince(session.startTime)
        let minutes = Int(interval) / 60
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.projectName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("Started \(Self.timeFormatter.string(from: session.startTime)) · \(duration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 10)
            Text(TokenFormatter.format(session.totalTokens))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
