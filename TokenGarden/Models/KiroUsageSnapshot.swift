import Foundation
import SwiftData

@Model
class KiroUsageSnapshot {
    var timestamp: Date
    var usedCredits: Double
    var remainingCredits: Double?
    var totalCredits: Double?
    var planName: String?
    var resetAt: Date?
    var rawOutput: String

    init(
        timestamp: Date = Date(),
        usedCredits: Double,
        remainingCredits: Double? = nil,
        totalCredits: Double? = nil,
        planName: String? = nil,
        resetAt: Date? = nil,
        rawOutput: String = ""
    ) {
        self.timestamp = timestamp
        self.usedCredits = usedCredits
        self.remainingCredits = remainingCredits
        self.totalCredits = totalCredits
        self.planName = planName
        self.resetAt = resetAt
        self.rawOutput = rawOutput
    }
}
