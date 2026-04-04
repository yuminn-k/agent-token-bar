# Deploy

## Release flow

1. 버전 업데이트
2. `git tag vX.Y.Z`
3. `git push origin main --tags`
4. GitHub Actions `release.yml`가 macOS에서 앱을 빌드하고 `AgentGarden.app.zip`을 릴리즈에 첨부

## Build command

```bash
xcodebuild -scheme TokenGarden -destination 'platform=macOS'   -derivedDataPath build/DerivedData   -configuration Release build
```
