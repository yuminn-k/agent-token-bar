import Foundation

struct TokenEvent: Sendable {
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let cachedInputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int
    let model: String?
    let projectName: String?
    let sessionId: String?
    let source: String
}
