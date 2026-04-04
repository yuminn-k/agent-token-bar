# Agent Garden

Codex 토큰과 Kiro CLI 크레딧 사용량을 확인하는 macOS 메뉴바 앱입니다.

## 지원 범위

- **Codex**: `~/.codex/sessions` / `~/.codex/archived_sessions`의 `token_count` 이벤트를 파싱해 일/주/월 히트맵, 프로젝트별 사용량, 활성 세션을 표시합니다.
- **Kiro CLI**: `kiro-cli chat --no-interactive /usage`를 주기적으로 호출해 현재 사이클 기준 사용량/잔여 크레딧을 표시합니다.

## 기능

- GitHub 스타일 히트맵
- 일/주/월 통계 카드
- Codex 5시간 / 7일 rate limit 카드
- Codex 프로젝트별 사용량, 활성 세션
- Kiro 현재 사이클 사용량 / 남은 크레딧 / 수동 새로고침
- 메뉴바 숫자/미니 그래프 모드

## 현재 제약

- Kiro 일별 히스토리는 **앱이 처음 성공적으로 `/usage`를 가져온 이후부터** 누적됩니다.
- 이 개발 환경에는 전체 Xcode 앱이 없어 로컬 빌드는 검증하지 못했습니다. 대신 GitHub Actions용 macOS 빌드 워크플로를 포함했습니다.

## 개발

GitHub Actions(macOS runner) 기준 빌드 명령:

```bash
xcodebuild -scheme TokenGarden -destination 'platform=macOS'   -derivedDataPath build/DerivedData   -configuration Release build
```

## 배포

`vX.Y.Z` 태그를 푸시하면 GitHub Actions가 Release 빌드를 생성하고 ZIP 아티팩트를 릴리즈에 첨부합니다.
