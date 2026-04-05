import SwiftUI

struct PopoverView: View {
    enum Tab: String, CaseIterable {
        case codex = "Codex"
        case kiro = "Kiro"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .codex: return "leaf.fill"
            case .kiro: return "terminal.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    @State private var activeTab: Tab = .codex

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent Garden")
                        .font(.title3.weight(.semibold))
                    Text("Codex tokens and Kiro credits in a cleaner menu bar dashboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue)
                            }
                            .font(.caption.weight(activeTab == tab ? .semibold : .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                activeTab == tab
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .foregroundStyle(activeTab == tab ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color.primary.opacity(0.02))

            Divider()

            Group {
                switch activeTab {
                case .codex:
                    CodexOverviewView()
                case .kiro:
                    KiroOverviewView()
                case .settings:
                    ScrollView {
                        SettingsView()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    }
                }
            }
        }
        .frame(width: 430, height: 690)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.18), value: activeTab)
    }
}
