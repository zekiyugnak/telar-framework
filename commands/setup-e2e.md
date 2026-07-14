---
id: setup-e2e
name: Setup E2E Testing
description: Set up end-to-end testing framework with CI integration
category: command
usage: /tl-telar:setup-e2e [framework]
example: /tl-telar:setup-e2e detox
phases:
  - name: Framework Selection
    progress: 0-25%
  - name: Configuration
    progress: 25-50%
  - name: Test Writing
    progress: 50-75%
  - name: CI Integration
    progress: 75-100%
---

# Setup E2E Testing

Set up end-to-end testing for mobile apps.

## Phase 1: Framework Selection (0-25%)

### Web App Detection

Before selecting among mobile frameworks, check whether the target is a **web app** rather than a mobile app: inspect `package.json` deps (`vite`, `@refinedev/*`, `@tanstack/react-router`, `astro`) or the app path for a web project structure. If the target is a web app (Vite / Refine / TanStack Router / Astro), delegate directly to `/tl-telar:setup-web-e2e` instead of proceeding with the mobile framework selection below — that command owns the Playwright-based web E2E setup (`supabase-e2e-harness`, `web-e2e-locators`, `web-e2e-catalog`, `web-e2e-review` skills, `web-e2e-testing-expert` agent). Stop this command's flow once delegation happens.

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
