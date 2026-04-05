import Foundation

struct CodexSessionContext: Sendable {
    let sessionId: String
    let cwd: String?

    var projectName: String? {
        cwd.map { URL(fileURLWithPath: $0).lastPathComponent }
    }
}

enum CodexParsedRecord: Sendable {
    case usage(TokenEvent)
    case rateLimit(CodexRateLimitState)
}

final class CodexSessionLogParser {
    let source = "codex"
    let watchPaths: [String]

    private var sessionContextByFile: [String: CodexSessionContext] = [:]

    init(homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.watchPaths = [
            "\(homeDirectory)/.codex/sessions",
            "\(homeDirectory)/.codex/archived_sessions"
        ]
    }

    func parse(line: String, filePath: String) -> [CodexParsedRecord] {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return []
        }

        switch type {
        case "session_meta":
            parseSessionMeta(json: json, filePath: filePath)
            return []
        case "event_msg":
            return parseEventMessage(json: json, filePath: filePath)
        default:
            return []
        }
    }

    private func parseSessionMeta(json: [String: Any], filePath: String) {
        guard let payload = json["payload"] as? [String: Any],
              let sessionId = payload["id"] as? String else {
            return
        }
        let cwd = payload["cwd"] as? String
        sessionContextByFile[filePath] = CodexSessionContext(sessionId: sessionId, cwd: cwd)
    }

    private func parseEventMessage(json: [String: Any], filePath: String) -> [CodexParsedRecord] {
        guard let payload = json["payload"] as? [String: Any],
              let payloadType = payload["type"] as? String,
              payloadType == "token_count" else {
            return []
        }

        var results: [CodexParsedRecord] = []

        if let rateLimits = parseRateLimits(payload: payload) {
            results.append(.rateLimit(rateLimits))
        }

        guard let info = payload["info"] as? [String: Any],
              let lastUsage = info["last_token_usage"] as? [String: Any],
              let totalTokens = lastUsage.intValue(for: "total_tokens"),
              totalTokens > 0 else {
            return results
        }

        let timestamp = Self.parseDate(json["timestamp"] as? String) ?? Date()
        let sessionContext = sessionContextByFile[filePath] ?? fallbackContext(for: filePath)

        let event = TokenEvent(
            timestamp: timestamp,
            inputTokens: lastUsage.intValue(for: "input_tokens") ?? 0,
            outputTokens: lastUsage.intValue(for: "output_tokens") ?? 0,
            cachedInputTokens: lastUsage.intValue(for: "cached_input_tokens") ?? 0,
            reasoningOutputTokens: lastUsage.intValue(for: "reasoning_output_tokens") ?? 0,
            totalTokens: totalTokens,
            model: nil,
            projectName: sessionContext?.projectName,
            sessionId: sessionContext?.sessionId,
            source: source
        )
        results.append(.usage(event))
        return results
    }

    private func parseRateLimits(payload: [String: Any]) -> CodexRateLimitState? {
        guard let rateLimits = payload["rate_limits"] as? [String: Any] else {
            return nil
        }

        let info = payload["info"] as? [String: Any]
        let lastUsage = info?["last_token_usage"] as? [String: Any]
        let totalUsage = info?["total_token_usage"] as? [String: Any]

        let primary = rateLimits["primary"] as? [String: Any]
        let secondary = rateLimits["secondary"] as? [String: Any]

        return CodexRateLimitState(
            fiveHourUsedPercent: primary?.doubleValue(for: "used_percent") ?? 0,
            fiveHourResetAt: primary?.dateValue(for: "resets_at"),
            sevenDayUsedPercent: secondary?.doubleValue(for: "used_percent") ?? 0,
            sevenDayResetAt: secondary?.dateValue(for: "resets_at"),
            planType: rateLimits["plan_type"] as? String,
            latestTurnTokens: lastUsage?.intValue(for: "total_tokens"),
            totalSessionTokens: totalUsage?.intValue(for: "total_tokens"),
            modelContextWindow: info?.intValue(for: "model_context_window")
        )
    }

    private func fallbackContext(for filePath: String) -> CodexSessionContext? {
        let sessionId = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        guard !sessionId.isEmpty else { return nil }
        return CodexSessionContext(sessionId: sessionId, cwd: nil)
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: string)
    }
}

private extension Dictionary where Key == String, Value == Any {
    func intValue(for key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? Double {
            return Int(value)
        }
        if let value = self[key] as? String {
            return Int(value)
        }
        return nil
    }

    func doubleValue(for key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let value = self[key] as? Int {
            return Double(value)
        }
        if let value = self[key] as? String {
            return Double(value.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    func dateValue(for key: String) -> Date? {
        guard let seconds = doubleValue(for: key) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
