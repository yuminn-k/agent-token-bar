import Testing
@testable import TokenGarden

@Test func parsesKiroUsageOutput() {
    let output = """
    Plan: Pro
    Used: 165 credits
    Remaining: 835 credits
    Reset: 2026-03-01
    """

    let summary = KiroUsageService.parseUsageOutput(output)
    #expect(summary != nil)
    #expect(summary?.usedCredits == 165)
    #expect(summary?.remainingCredits == 835)
    #expect(summary?.totalCredits == 1000)
    #expect(summary?.planName == "Pro")
}
