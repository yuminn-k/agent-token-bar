import Foundation
import SwiftData

@Model
class KiroDailyUsage {
    @Attribute(.unique) var date: Date
    var creditsUsed: Double

    init(date: Date, creditsUsed: Double = 0) {
        self.date = date
        self.creditsUsed = creditsUsed
    }
}
