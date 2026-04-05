import SwiftUI

struct StatsView: View {
    let todayTokens: Int
    let weekTokens: Int
    let monthTokens: Int

    var body: some View {
        PanelCard(
            title: "Codex Totals",
            subtitle: "High-level usage across common time windows",
            systemImage: "chart.bar.fill"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                MetricTile(label: "Today", value: TokenFormatter.format(todayTokens), note: "Current day")
                MetricTile(label: "This Week", value: TokenFormatter.format(weekTokens), note: "Monday → now")
                MetricTile(label: "This Month", value: TokenFormatter.format(monthTokens), note: "Month to date")
            }
        }
    }
}
