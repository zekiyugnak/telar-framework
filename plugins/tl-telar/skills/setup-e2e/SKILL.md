---
name: "setup-e2e"
description: "Set up end-to-end testing framework with CI integration"
source_type: "command"
source_file: "commands/setup-e2e.md"
---

# setup-e2e

Migrated from `commands/setup-e2e.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:setup-e2e`; invoke it as `$setup-e2e` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Setup E2E Testing

Set up end-to-end testing for mobile apps.

## Phase 1: Framework Selection (0-25%)

### Load Agents
```yaml
agents:
  - mobile-e2e-testing-expert
```

### Framework Comparison
```markdown
| Framework | RN Support | Flutter | Learning Curve | CI Support |
|-----------|------------|---------|----------------|------------|
| Detox | Excellent | No | Medium | Good |
| Maestro | Good | Good | Low | Good |
| Appium | Good | Good | High | Excellent |
| Patrol | No | Excellent | Medium | Good |
```

### Selection Criteria
- Project framework (RN/Flutter)
- Team experience
- CI/CD requirements
- Test complexity needs

### Output
- Framework selected
- Rationale documented

## Phase 2: Configuration (25-50%)

### Detox Setup (React Native)
```bash
# Install
yarn add -D detox jest-circus

# Initialize
npx detox init
```

```javascript
// .detoxrc.js
module.exports = {
  testRunner: {
    args: {
      config: 'e2e/jest.config.js',
    },
    jest: {
      setupTimeout: 120000,
    },
  },
  apps: {
    'ios.release': {
      type: 'ios.app',
      binaryPath: 'ios/build/MyApp.app',
      build: 'xcodebuild -workspace ios/MyApp.xcworkspace -scheme MyApp -configuration Release -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'android.release': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/release/app-release.apk',
      build: 'cd android && ./gradlew assembleRelease assembleAndroidTest -DtestBuildType=release',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: { type: 'iPhone 15' },
    },
    emulator: {
      type: 'android.emulator',
      device: { avdName: 'Pixel_6_API_34' },
    },
  },
  configurations: {
    'ios.release': {
      device: 'simulator',
      app: 'ios.release',
    },
    'android.release': {
      device: 'emulator',
      app: 'android.release',
    },
  },
}
```

### Maestro Setup
```bash
# Install Maestro
curl -Ls "https://get.maestro.mobile.dev" | bash

# Initialize
mkdir -p .maestro
```

```yaml
# .maestro/config.yaml
appId: com.myapp
```

### Flutter Integration Test Setup
```yaml
# pubspec.yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
```

### Output
- Framework installed
- Configuration complete

## Phase 3: Test Writing (50-75%)

### Load Skills
```yaml
skills:
  - mock-strategies
```

### Test Structure
```
e2e/
├── flows/
│   ├── auth.test.ts
│   ├── onboarding.test.ts
│   └── purchase.test.ts
├── helpers/
│   ├── auth.ts
│   └── navigation.ts
├── jest.config.js
└── setup.ts
```

### Detox Test Example
```typescript
// e2e/flows/auth.test.ts
describe('Authentication', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true })
  })

  beforeEach(async () => {
    await device.reloadReactNative()
  })

  it('should show login screen', async () => {
    await expect(element(by.id('login-screen'))).toBeVisible()
  })

  it('should login with valid credentials', async () => {
    await element(by.id('email-input')).typeText('test@example.com')
    await element(by.id('password-input')).typeText('password123')
    await element(by.id('login-button')).tap()

    await waitFor(element(by.id('home-screen')))
      .toBeVisible()
      .withTimeout(5000)
  })

  it('should show error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com')
    await element(by.id('password-input')).typeText('wrongpass')
    await element(by.id('login-button')).tap()

    await expect(element(by.text('Invalid credentials'))).toBeVisible()
  })
})
```

### Maestro Test Example
```yaml
# .maestro/flows/auth.yaml
appId: com.myapp
---
- launchApp:
    clearState: true
- assertVisible: "Login"
- tapOn:
    id: "email-input"
- inputText: "test@example.com"
- tapOn:
    id: "password-input"
- inputText: "password123"
- tapOn: "Login"
- assertVisible: "Welcome"
```

### Test Helpers
```typescript
// e2e/helpers/auth.ts
export async function login(email: string, password: string) {
  await element(by.id('email-input')).typeText(email)
  await element(by.id('password-input')).typeText(password)
  await element(by.id('login-button')).tap()
}

export async function logout() {
  await element(by.id('settings-tab')).tap()
  await element(by.id('logout-button')).tap()
}
```

### Output
- Core tests written
- Helper functions created

## Phase 4: CI Integration (75-100%)

### Load Skills
```yaml
skills:
  - ci-testing-integration
```

### GitHub Actions (Detox)
```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Install pods
        run: cd ios && pod install

      - name: Build for testing
        run: npx detox build --configuration ios.release

      - name: Run E2E tests
        run: npx detox test --configuration ios.release --headless

  e2e-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Start emulator
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          script: |
            yarn install --frozen-lockfile
            npx detox build --configuration android.release
            npx detox test --configuration android.release
```

### Maestro CI
```yaml
name: Maestro E2E

on: [push]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: mobile-dev-inc/action-maestro-cloud@v1
        with:
          api-key: ${{ secrets.MAESTRO_CLOUD_API_KEY }}
          app-file: app.apk
```

### Output
- CI pipeline configured
- E2E tests running on PR

## Completion Checklist

- [ ] Framework selected and installed
- [ ] Configuration complete
- [ ] Core test flows written
- [ ] Test helpers created
- [ ] CI pipeline configured
- [ ] Documentation updated
