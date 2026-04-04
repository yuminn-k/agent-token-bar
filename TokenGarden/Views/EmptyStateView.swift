import SwiftUI

enum EmptyStateReason {
    case noCodexData
    case noCodexLogs
    case noKiroData
    case kiroNotInstalled
    case kiroNotLoggedIn
    case noPermission(String)
}

struct EmptyStateView: View {
    let reason: EmptyStateReason

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if case .kiroNotLoggedIn = reason {
                Text("Run `kiro-cli login --use-device-flow` once, then refresh.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: String {
        switch reason {
        case .noCodexData, .noKiroData:
            return "leaf.fill"
        case .noCodexLogs:
            return "questionmark.folder.fill"
        case .kiroNotInstalled:
            return "terminal.fill"
        case .kiroNotLoggedIn:
            return "person.crop.circle.badge.exclamationmark"
        case .noPermission:
            return "lock.fill"
        }
    }

    private var title: String {
        switch reason {
        case .noCodexData:
            return "No Codex Data Yet"
        case .noCodexLogs:
            return "Codex Logs Not Found"
        case .noKiroData:
            return "No Kiro Data Yet"
        case .kiroNotInstalled:
            return "Kiro CLI Not Installed"
        case .kiroNotLoggedIn:
            return "Kiro CLI Login Required"
        case .noPermission:
            return "Permission Required"
        }
    }

    private var message: String {
        switch reason {
        case .noCodexData:
            return "Start using Codex and your garden will grow here."
        case .noCodexLogs:
            return "The ~/.codex/sessions folder was not found."
        case .noKiroData:
            return "Daily Kiro credits begin tracking after the first successful refresh."
        case .kiroNotInstalled:
            return "Install Kiro CLI to track credits and remaining quota."
        case .kiroNotLoggedIn:
            return "Kiro CLI is installed, but this machine is not logged in."
        case .noPermission(let path):
            return "Cannot access \(path). Please grant Full Disk Access if needed."
        }
    }
}
