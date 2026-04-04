import SwiftUI

struct PopoverView: View {
    enum Tab {
        case codex
        case kiro
        case settings
    }

    @State private var activeTab: Tab = .codex

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { activeTab = .codex }) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(activeTab == .codex ? .primary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    Button(action: { activeTab = .kiro }) {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(activeTab == .kiro ? .primary : .tertiary)
                    }
                    .buttonStyle(.plain)
                    Button(action: { activeTab = .settings }) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(activeTab == .settings ? .primary : .tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Group {
                switch activeTab {
                case .codex:
                    CodexOverviewView()
                case .kiro:
                    KiroOverviewView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .frame(width: 340)
        .animation(nil, value: activeTab)
    }

    private var title: String {
        switch activeTab {
        case .codex:
            return "Agent Garden · Codex"
        case .kiro:
            return "Agent Garden · Kiro"
        case .settings:
            return "Agent Garden · Settings"
        }
    }
}
