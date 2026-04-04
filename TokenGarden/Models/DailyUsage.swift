import Foundation
import SwiftData

@Model
class DailyUsage {
    @Attribute(.unique) var date: Date
    var totalTokens: Int
    var inputTokens: Int
    var outputTokens: Int
    var cachedInputTokens: Int
    var reasoningOutputTokens: Int
    @Relationship(deleteRule: .cascade, inverse: \ProjectUsage.dailyUsage)
    var projectBreakdowns: [ProjectUsage]

    init(date: Date) {
        self.date = date
        self.totalTokens = 0
        self.inputTokens = 0
        self.outputTokens = 0
        self.cachedInputTokens = 0
        self.reasoningOutputTokens = 0
        self.projectBreakdowns = []
    }
}
