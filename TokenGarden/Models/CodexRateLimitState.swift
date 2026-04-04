import Foundation

struct CodexRateLimitState: Equatable, Sendable {
    var fiveHourUsedPercent: Double
    var fiveHourResetAt: Date?
    var sevenDayUsedPercent: Double
    var sevenDayResetAt: Date?
    var planType: String?
    var latestTurnTokens: Int?
    var totalSessionTokens: Int?
    var modelContextWindow: Int?
}
