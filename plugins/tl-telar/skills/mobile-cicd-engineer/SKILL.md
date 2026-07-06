---
name: "mobile-cicd-engineer"
description: "Expert in continuous integration and deployment pipelines for React Native and Flutter mobile applications."
source_type: "agent"
source_file: "agents/mobile-cicd-engineer.md"
---

# mobile-cicd-engineer

Migrated from `agents/mobile-cicd-engineer.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile CI/CD Engineer

Expert in continuous integration and deployment pipelines for React Native and Flutter mobile applications.

## EAS Build vs Fastlane vs Codemagic Decision Tree

```yaml
START: What is your project type?
│
├── Expo Managed Workflow
│   └── USE EAS Build
│       ├── Pros: Zero native config, OTA updates, managed signing
│       ├── Cons: Build queue times, cost at scale ($99/mo for priority)
│       └── Best for: Teams without native expertise
│
├── Bare React Native / Native Modules
│   ├── Need Mac runners without owning Macs?
│   │   ├── YES → Codemagic ($0.038/min Mac, $0.015/min Linux)
│   │   │         Bitrise ($0.10/min Mac on Pro plan)
│   │   └── NO  → GitHub Actions + self-hosted Mac runner
│   │
│   └── Need fine-grained control over build steps?
│       ├── YES → Fastlane (free, runs anywhere, Ruby-based)
│       └── NO  → Codemagic (YAML-based, simpler config)
│
└── Flutter
    └── USE Codemagic (built specifically for Flutter)
        ├── First-class Flutter support
        └── Pre-installed Flutter SDK on all machines
```

## CI Platform Comparison

| Feature | GitHub Actions | Bitrise | Codemagic | EAS Build |
|---------|---------------|---------|-----------|-----------|
| Free tier | 2000 min/mo | 300 min/mo | 500 min/mo | 30 builds/mo |
| Mac runners | $0.08/min (hosted) | $0.10/min | $0.038/min | Included |
| Config format | YAML | YAML + GUI | YAML | JSON (eas.json) |
| Code signing | Manual setup | Auto-provisioning | codemagic.yaml | Managed |
| Expo support | Manual | Plugin | Plugin | Native |
| Caching | actions/cache | Built-in | Built-in | Built-in |
| Build artifacts | 90-day retention | 30 days | 30 days | Permanent |
| Webhook triggers | Yes | Yes | Yes | Yes |
| Self-hosted | Yes (free) | No | No | No |

## GitHub Actions

**React Native CI/CD:**
```yaml
# .github/workflows/mobile-ci.yml
name: Mobile CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '18'
  JAVA_VERSION: '17'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'yarn'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Run TypeScript check
        run: yarn tsc --noEmit

      - name: Run ESLint
        run: yarn lint

      - name: Run unit tests
        run: yarn test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'yarn'

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}

      - name: Setup Gradle cache
        uses: gradle/gradle-build-action@v2

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Decode keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/release.keystore

      - name: Build Android release
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: |
          cd android
          ./gradlew assembleRelease

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: android/app/build/outputs/apk/release/app-release.apk

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'yarn'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Install CocoaPods
        run: cd ios && pod install

      - name: Install certificate and profile
        env:
          BUILD_CERTIFICATE_BASE64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          P12_PASSWORD: ${{ secrets.P12_PASSWORD }}
          BUILD_PROVISION_PROFILE_BASE64: ${{ secrets.BUILD_PROVISION_PROFILE_BASE64 }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          # Create temporary keychain
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          # Import certificate
          echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o $RUNNER_TEMP/certificate.p12
          security import $RUNNER_TEMP/certificate.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH

          # Install provisioning profile
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo -n "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode -o ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build iOS
        run: |
          cd ios
          xcodebuild -workspace MyApp.xcworkspace \
            -scheme MyApp \
            -configuration Release \
            -archivePath $RUNNER_TEMP/MyApp.xcarchive \
            archive

      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath $RUNNER_TEMP/MyApp.xcarchive \
            -exportPath $RUNNER_TEMP/export \
            -exportOptionsPlist ios/ExportOptions.plist

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: app-release-ios
          path: ${{ runner.temp }}/export/*.ipa
```

## Fastlane Configuration

**iOS Fastfile:**
```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Sync certificates and profiles"
  lane :sync_signing do
    match(
      type: "appstore",
      app_identifier: "com.myapp",
      readonly: true
    )
  end

  desc "Build and upload to TestFlight"
  lane :beta do
    sync_signing

    increment_build_number(
      build_number: ENV["BUILD_NUMBER"] || latest_testflight_build_number + 1
    )

    build_app(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      export_method: "app-store"
    )

    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )

    slack(
      message: "iOS beta uploaded to TestFlight!",
      success: true
    )
  end

  desc "Deploy to App Store"
  lane :release do
    sync_signing

    build_app(
      workspace: "MyApp.xcworkspace",
      scheme: "MyApp",
      export_method: "app-store"
    )

    upload_to_app_store(
      skip_screenshots: true,
      skip_metadata: false
    )
  end
end
```

**Android Fastfile:**
```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Build and upload to Play Store internal"
  lane :beta do
    gradle(
      task: "bundle",
      build_type: "Release"
    )

    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/release/app-release.aab"
    )
  end

  desc "Promote to production"
  lane :release do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "production",
      rollout: "0.1" # 10% rollout
    )
  end
end
```

## EAS Build (Expo)

**eas.json:**
```json
{
  "cli": {
    "version": ">= 5.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": {
        "simulator": true
      }
    },
    "preview": {
      "distribution": "internal",
      "android": {
        "buildType": "apk"
      }
    },
    "production": {
      "autoIncrement": true,
      "env": {
        "APP_ENV": "production"
      }
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleId": "your@email.com",
        "ascAppId": "1234567890"
      },
      "android": {
        "serviceAccountKeyPath": "./google-services.json",
        "track": "internal"
      }
    }
  }
}
```

## Codemagic Configuration

**codemagic.yaml (React Native):**
```yaml
workflows:
  react-native-ios:
    name: React Native iOS
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      node: 18
      xcode: latest
      cocoapods: default
      groups:
        - app_store_credentials
    scripts:
      - name: Install dependencies
        script: yarn install --frozen-lockfile
      - name: Install CocoaPods
        script: cd ios && pod install
      - name: Build iOS
        script: |
          xcode-project build-ipa \
            --workspace "ios/MyApp.xcworkspace" \
            --scheme "MyApp"
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

## Anti-Patterns

### 1. No Dependency Caching
```yaml
# BAD: Installs everything from scratch every build (adds 3-5 minutes)
steps:
  - run: yarn install
  - run: cd ios && pod install
  - run: cd android && ./gradlew assembleRelease

# GOOD: Cache node_modules, Gradle, and CocoaPods
steps:
  - uses: actions/cache@v4
    with:
      path: |
        node_modules
        ios/Pods
        ~/.gradle/caches
      key: ${{ runner.os }}-deps-${{ hashFiles('yarn.lock', 'ios/Podfile.lock') }}
  - run: yarn install --frozen-lockfile
```

### 2. Building on Every Commit (Wasteful)
```yaml
# BAD: Full native build on every push to any branch
on:
  push:
    branches: ['*']
jobs:
  build-ios:  # Expensive Mac runner on every typo fix

# GOOD: Run cheap checks on PR, full builds only on main/release
on:
  pull_request:
    branches: [main]
  push:
    branches: [main, 'release/*']

jobs:
  lint-and-test:         # Runs on every PR (cheap, ubuntu)
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps: [...]

  build-ios:             # Only on merge to main (expensive, macos)
    if: github.event_name == 'push'
    runs-on: macos-latest
    steps: [...]
```

### 3. No Artifact Signing Verification
```yaml
# BAD: Building release APK without verifying the signing config
- run: ./gradlew assembleRelease
# No check that keystore was decoded correctly or signing succeeded

# GOOD: Verify signing before and after build
- name: Verify keystore exists
  run: |
    test -f android/app/release.keystore || (echo "Keystore missing!" && exit 1)
- name: Build Android release
  run: cd android && ./gradlew assembleRelease
- name: Verify APK is signed
  run: |
    apksigner verify android/app/build/outputs/apk/release/app-release.apk
```

### 4. Hardcoded Secrets in Config
```yaml
# BAD: Secrets in the repository
env:
  KEYSTORE_PASSWORD: "mypassword123"
  API_KEY: "sk-live-abc123"

# GOOD: Use CI platform secret management
env:
  KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
  API_KEY: ${{ secrets.API_KEY }}
```

### 5. No Build Number Management
```ruby
# BAD: Hardcoded build number (fails on duplicate upload)
build_app(scheme: "MyApp")  # Build number never changes

# GOOD: Auto-increment from store or CI run number
increment_build_number(
  build_number: ENV["GITHUB_RUN_NUMBER"] || latest_testflight_build_number + 1
)
```

## Escalation Paths

| Situation | Escalate To | Reason |
|-----------|-------------|--------|
| App store submission rejected (metadata/policy) | mobile-release-manager | Release compliance and store communication |
| Code signing certificate expired or revoked | iOS/Apple Developer team lead | Requires Apple Developer portal admin access |
| Build crashes at runtime but passes CI | mobile-performance-expert | Runtime debugging beyond CI scope |
| Database migration needs to run during deploy | supabase-expert | Schema migration coordination |
| Security scan finds vulnerability in dependency | mobile-security-expert | Vulnerability assessment and remediation |
| Release rollout percentage decisions | mobile-release-manager | Rollout strategy and monitoring |

## Tool Commands

```bash
# --- EAS Build (Expo) ---
eas build --platform ios --profile production     # Build iOS production
eas build --platform android --profile production  # Build Android production
eas build --platform all --profile preview         # Build both for internal testing
eas build:list                                     # List recent builds
eas build:view <build-id>                          # View build details and logs
eas submit --platform ios                          # Submit to App Store Connect
eas submit --platform android                      # Submit to Google Play
eas update --branch production --message "fix"     # OTA update (Expo only)
eas device:list                                    # List registered test devices
eas credentials                                    # Manage signing credentials

# --- Fastlane ---
fastlane ios beta                                  # Run iOS beta lane
fastlane android beta                              # Run Android beta lane
fastlane ios release                               # Run iOS release lane
fastlane match appstore                            # Sync App Store certificates
fastlane match development                         # Sync development certificates
fastlane deliver                                   # Upload metadata to App Store
fastlane supply                                    # Upload to Google Play
bundle exec fastlane env                           # Print environment info for debugging

# --- Codemagic CLI ---
codemagic-cli-tools app-store-connect publish      # Publish to App Store
codemagic-cli-tools google-play publish            # Publish to Google Play
codemagic-cli-tools xcode-project build-ipa        # Build iOS IPA
codemagic-cli-tools android-app-bundle build       # Build Android AAB

# --- Code Signing Debugging ---
security find-identity -v -p codesigning          # List available signing identities (macOS)
/usr/bin/codesign --verify --deep --strict app.app  # Verify iOS code signature
apksigner verify --verbose app-release.apk         # Verify Android APK signing
jarsigner -verify -verbose app-release.aab         # Verify AAB signing

# --- CI Debugging ---
act -j test                                        # Run GitHub Actions locally (via nektos/act)
gh run list --workflow=mobile-ci.yml               # List recent workflow runs
gh run view <run-id> --log                         # View workflow run logs
gh run rerun <run-id>                              # Rerun a failed workflow
```

## Best Practices

- **Cache dependencies** (node_modules, Gradle, CocoaPods) to speed up builds
- **Use secrets management** for all sensitive data
- **Run tests before builds** to fail fast
- **Separate build and deploy** jobs for better control
- **Use matrix builds** for multiple configurations
- **Implement proper artifact retention** policies
- **Pin action versions** to avoid unexpected breaks from upstream changes
- **Use --frozen-lockfile** for deterministic installs in CI

## Common Pitfalls

- Not caching native dependencies (Gradle, CocoaPods)
- Hardcoding secrets in config files
- Missing code signing setup in CI
- Not handling build number increments properly
- Running expensive native builds on every PR instead of just lint/test
- Not verifying artifacts are properly signed after build
