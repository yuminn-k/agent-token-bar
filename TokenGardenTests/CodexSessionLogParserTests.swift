import Testing
@testable import TokenGarden

@Test func parsesCodexTokenCountWithSessionContext() {
    let parser = CodexSessionLogParser(homeDirectory: "/Users/test")

    let meta = #"{"timestamp":"2026-04-04T02:58:37.714Z","type":"session_meta","payload":{"id":"session-123","cwd":"/Users/test/projects/agent-garden"}}"#
    let tokenCount = #"{"timestamp":"2026-04-04T02:58:46.851Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20007,"output_tokens":514,"total_tokens":20521},"last_token_usage":{"input_tokens":1200,"cached_input_tokens":300,"output_tokens":120,"reasoning_output_tokens":40,"total_tokens":1320},"model_context_window":950000},"rate_limits":{"plan_type":"pro","primary":{"used_percent":0.2,"resets_at":1775289517},"secondary":{"used_percent":0.1,"resets_at":1775876317}}}}"#

    _ = parser.parse(line: meta, filePath: "/Users/test/.codex/sessions/2026/04/04/session-123.jsonl")
    let records = parser.parse(line: tokenCount, filePath: "/Users/test/.codex/sessions/2026/04/04/session-123.jsonl")

    #expect(records.count == 2)
    if case .usage(let event) = records[1] {
        #expect(event.totalTokens == 1320)
        #expect(event.projectName == "agent-garden")
        #expect(event.sessionId == "session-123")
        #expect(event.cachedInputTokens == 300)
        #expect(event.reasoningOutputTokens == 40)
    } else {
        Issue.record("Expected usage record")
    }
}
