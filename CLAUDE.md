# Agent Garden

Codex + Kiro CLI 사용량을 추적하는 macOS 메뉴바 앱.

## 핵심 아키텍처

- **Codex**: `CodexSessionLogParser`가 `~/.codex/sessions/**/*.jsonl`의 `token_count` 이벤트를 읽음
- **Kiro**: `KiroUsageService`가 `kiro-cli chat --no-interactive /usage`를 폴링
- **저장소**: SwiftData (`DailyUsage`, `SessionUsage`, `KiroUsageSnapshot`, `KiroDailyUsage`)
- **UI**: Codex / Kiro / Settings 탭

## 주의

- 메뉴바 숫자는 Codex 당일 토큰 기준
- Kiro는 로그인 상태가 아니면 사용량을 읽지 못함
- 로컬 검증은 `swift build --scratch-path .build/spm`, 릴리스 패키징은 `scripts/package_app.sh`
