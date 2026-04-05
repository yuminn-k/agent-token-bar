import SwiftUI

enum ProjectTimeRange: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}

struct ProjectListView: View {
    let todayProjects: [(name: String, tokens: Int)]
    let weekProjects: [(name: String, tokens: Int)]
    let monthProjects: [(name: String, tokens: Int)]
    var selectedDayProjects: [(name: String, tokens: Int)]?
    var selectedDayLabel: String?
    @State private var selectedRange: ProjectTimeRange = .week

    private var activeProjects: [(name: String, tokens: Int)] {
        if let selectedDayProjects {
            return selectedDayProjects.sorted { $0.tokens > $1.tokens }
        }
        switch selectedRange {
        case .today: return todayProjects.sorted { $0.tokens > $1.tokens }
        case .week: return weekProjects.sorted { $0.tokens > $1.tokens }
        case .month: return monthProjects.sorted { $0.tokens > $1.tokens }
        }
    }

    private var totalTokens: Int {
        activeProjects.reduce(0) { $0 + $1.tokens }
    }

    var body: some View {
        PanelCard(
            title: selectedDayLabel ?? "Projects",
            subtitle: "Top token-consuming repositories and folders",
            systemImage: "folder.fill"
        ) {
            if selectedDayProjects == nil {
                SegmentedPillBar(ProjectTimeRange.self, selection: $selectedRange) { $0.rawValue }
            }

            if activeProjects.isEmpty {
                Text("No project activity for this period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let items = Array(activeProjects.prefix(6))
                VStack(spacing: 10) {
                    ForEach(items, id: \.name) { project in
                        projectRow(project)
                    }
                }
            }
        }
    }

    private func projectRow(_ project: (name: String, tokens: Int)) -> some View {
        let ratio = totalTokens > 0 ? Double(project.tokens) / Double(totalTokens) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(project.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(TokenFormatter.format(project.tokens))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(Int(ratio * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
            ProgressView(value: ratio)
                .tint(.accentColor)
        }
    }
}
