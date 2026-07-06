---
name: "setup-cicd"
description: "Configure CI/CD pipeline for mobile app with build, test, and deploy automation"
source_type: "command"
source_file: "commands/setup-cicd.md"
---

# setup-cicd

Migrated from `commands/setup-cicd.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:setup-cicd`; invoke it as `$setup-cicd` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Setup CI/CD

Configure CI/CD pipeline for mobile applications.

## Phase 1: Platform Selection (0-25%)

### Load Agents
```yaml
agents:
  - mobile-cicd-engineer
```

### CI/CD Platform Comparison
```markdown
| Platform | iOS Build | Android | Free Tier | Mobile Focus |
|----------|-----------|---------|-----------|--------------|
| GitHub Actions | ✅ | ✅ | 2000 min/mo | General |
| Bitrise | ✅ | ✅ | Limited | Mobile-first |
| CircleCI | ✅ | ✅ | 6000 min/mo | General |
| Codemagic | ✅ | ✅ | 500 min/mo | Mobile-first |
| EAS Build | ✅ | ✅ | Limited | Expo-native |
```

### Selection Criteria
- iOS build requirements (macOS runners)
- Budget constraints
- Team familiarity
- Integration needs

### Output
- CI/CD platform selected
- Account configured

## Phase 2: Build Config (25-50%)

### Load Skills
```yaml
skills:
  - ios-provisioning
  - android-signing
```

### GitHub Actions - React Native
```yaml
# .github/workflows/build.yml
name: Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'
      - run: yarn install --frozen-lockfile
      - uses: actions/cache@v4
        with:
          path: node_modules
          key: modules-${{ hashFiles('yarn.lock') }}

  build-android:
    needs: install
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: actions/cache@v4
        with:
          path: node_modules
          key: modules-${{ hashFiles('yarn.lock') }}
      - uses: gradle/gradle-build-action@v2
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
        run: echo $KEYSTORE_BASE64 | base64 -d > android/app/release.keystore

      - name: Build Android
        env:
          MYAPP_RELEASE_STORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          MYAPP_RELEASE_KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: |
          cd android
          ./gradlew assembleRelease

      - uses: actions/upload-artifact@v4
        with:
          name: android-release
          path: android/app/build/outputs/apk/release/

  build-ios:
    needs: install
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - uses: actions/cache@v4
        with:
          path: node_modules
          key: modules-${{ hashFiles('yarn.lock') }}

      - name: Install CocoaPods
        run: |
          cd ios
          pod install

      - name: Setup certificates
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_URL: ${{ secrets.MATCH_GIT_URL }}
        run: fastlane match appstore --readonly

      - name: Build iOS
        run: |
          xcodebuild -workspace ios/MyApp.xcworkspace \
            -scheme MyApp \
            -configuration Release \
            -archivePath build/MyApp.xcarchive \
            archive

      - uses: actions/upload-artifact@v4
        with:
          name: ios-release
          path: build/
```

### Codemagic - Flutter
```yaml
# codemagic.yaml
workflows:
  ios-workflow:
    name: iOS Production
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Build iOS
        script: flutter build ipa --release
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_API_KEY

  android-workflow:
    name: Android Production
    max_build_duration: 60
    environment:
      flutter: stable
      java: 17
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Build Android
        script: flutter build appbundle --release
    artifacts:
      - build/app/outputs/bundle/release/*.aab
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
```

### Output
- Build workflows created
- Secrets configured

## Phase 3: Test Integration (50-75%)

### Load Skills
```yaml
skills:
  - ci-testing-integration
```

### Test Workflow
```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'
      - run: yarn install --frozen-lockfile
      - run: yarn lint
      - run: yarn typecheck

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'
      - run: yarn install --frozen-lockfile
      - run: yarn test --coverage --ci
      - uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info

  e2e-test:
    runs-on: macos-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: yarn install --frozen-lockfile
      - run: npx detox build --configuration ios.release
      - run: npx detox test --configuration ios.release --headless
```

### Output
- Test workflows configured
- Coverage reporting enabled

## Phase 4: Deployment (75-100%)

### Deployment Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # ... build steps ...

      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_JSON }}
          packageName: com.myapp
          releaseFiles: android/app/build/outputs/bundle/release/*.aab
          track: internal
          status: completed

  deploy-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      # ... build steps ...

      - name: Deploy to App Store
        run: |
          fastlane deliver --ipa build/MyApp.ipa \
            --skip_screenshots \
            --skip_metadata

  notify:
    needs: [deploy-android, deploy-ios]
    runs-on: ubuntu-latest
    steps:
      - name: Notify Slack
        uses: slackapi/slack-github-action@v1
        with:
          channel-id: 'releases'
          slack-message: 'New release ${{ github.ref_name }} deployed!'
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Output
- Deployment automation configured
- Notifications set up

## Completion Checklist

- [ ] CI platform configured
- [ ] Build workflows for iOS and Android
- [ ] Test workflows (lint, unit, E2E)
- [ ] Code signing secrets configured
- [ ] Deployment automation
- [ ] Notifications configured
- [ ] Documentation updated
