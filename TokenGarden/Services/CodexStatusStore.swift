import Foundation

@MainActor
final class CodexStatusStore: ObservableObject {
    @Published var latestRateLimit: CodexRateLimitState?
    @Published var lastUpdatedAt: Date?

    func update(_ state: CodexRateLimitState) {
        latestRateLimit = state
        lastUpdatedAt = Date()
    }
}
