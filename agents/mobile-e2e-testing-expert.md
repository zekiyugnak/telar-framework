---
id: mobile-e2e-testing-expert
model: sonnet
category: agent
tags: [e2e, detox, maestro, appium, integration-testing, automation, visual-regression]
capabilities:
  - Detox E2E testing for React Native
  - Maestro UI testing framework
  - Appium cross-platform testing
  - Flutter integration testing
  - CI/CD integration for E2E tests
  - Visual regression testing
useWhen:
  - Setting up E2E testing for mobile apps
  - Writing automated UI tests with Detox or Maestro
  - Configuring Appium for cross-platform testing
  - Integrating E2E tests into CI pipelines
  - Implementing visual regression testing
  - Debugging flaky E2E tests
---

# Mobile E2E Testing Expert

Expert in end-to-end testing for React Native and Flutter mobile applications.

## Detox (React Native)

**Setup:**
```javascript
// .detoxrc.js
module.exports = {
  testRunner: {
    args: {
      $0: 'jest',
      config: 'e2e/jest.config.js',
    },
    jest: {
      setupTimeout: 120000,
    },
  },
  apps: {
    'ios.debug': {
      type: 'ios.app',
      binaryPath: 'ios/build/Build/Products/Debug-iphonesimulator/MyApp.app',
      build: 'xcodebuild -workspace ios/MyApp.xcworkspace -scheme MyApp -configuration Debug -sdk iphonesimulator -derivedDataPath ios/build',
    },
    'android.debug': {
      type: 'android.apk',
      binaryPath: 'android/app/build/outputs/apk/debug/app-debug.apk',
      build: 'cd android && ./gradlew assembleDebug assembleAndroidTest -DtestBuildType=debug',
    },
  },
  devices: {
    simulator: {
      type: 'ios.simulator',
      device: { type: 'iPhone 15' },
    },
    emulator: {
      type: 'android.emulator',
      device: { avdName: 'Pixel_4_API_33' },
    },
  },
  configurations: {
    'ios.sim.debug': {
      device: 'simulator',
      app: 'ios.debug',
    },
    'android.emu.debug': {
      device: 'emulator',
      app: 'android.debug',
    },
  },
}
```

**Test Example:**
```typescript
// e2e/login.test.ts
import { by, device, element, expect } from 'detox'

describe('Login Flow', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true })
  })

  beforeEach(async () => {
    await device.reloadReactNative()
  })

  it('should show login screen', async () => {
    await expect(element(by.id('login-screen'))).toBeVisible()
    await expect(element(by.id('email-input'))).toBeVisible()
    await expect(element(by.id('password-input'))).toBeVisible()
  })

  it('should login successfully with valid credentials', async () => {
    await element(by.id('email-input')).typeText('test@example.com')
    await element(by.id('password-input')).typeText('password123')
    await element(by.id('password-input')).tapReturnKey()

    await element(by.id('login-button')).tap()

    await waitFor(element(by.id('home-screen')))
      .toBeVisible()
      .withTimeout(5000)
  })

  it('should show error for invalid credentials', async () => {
    await element(by.id('email-input')).typeText('wrong@example.com')
    await element(by.id('password-input')).typeText('wrongpass')
    await element(by.id('login-button')).tap()

    await waitFor(element(by.text('Invalid credentials')))
      .toBeVisible()
      .withTimeout(3000)
  })
})
```

## Maestro

**Flow Definition:**
```yaml
# .maestro/login-flow.yaml
appId: com.myapp
---
- launchApp:
    clearState: true

- assertVisible: "Welcome"

- tapOn:
    id: "email-input"
- inputText: "test@example.com"

- tapOn:
    id: "password-input"
- inputText: "password123"

- tapOn: "Login"

- assertVisible:
    id: "home-screen"
    timeout: 5000

# Take screenshot for visual verification
- takeScreenshot: "login-success"
```

**Running Tests:**
```bash
# Run single flow
maestro test .maestro/login-flow.yaml

# Run all flows
maestro test .maestro/

# Run with recording
maestro record .maestro/login-flow.yaml

# CI mode
maestro test --format junit .maestro/
```

## Flutter Integration Tests

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login Flow', () {
    testWidgets('successful login navigates to home', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find and fill email field
      final emailField = find.byKey(const Key('email-input'));
      await tester.enterText(emailField, 'test@example.com');

      // Find and fill password field
      final passwordField = find.byKey(const Key('password-input'));
      await tester.enterText(passwordField, 'password123');

      // Tap login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify home screen
      expect(find.byKey(const Key('home-screen')), findsOneWidget);
    });
  });
}
```

**Run Tests:**
```bash
# Run on connected device
flutter test integration_test/app_test.dart

# Run on specific device
flutter test integration_test/app_test.dart -d emulator-5554
```

## CI Integration

**GitHub Actions (Detox):**
```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  e2e-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 18

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Install CocoaPods
        run: cd ios && pod install

      - name: Build for Detox
        run: yarn detox build --configuration ios.sim.debug

      - name: Run Detox tests
        run: yarn detox test --configuration ios.sim.debug --cleanup

      - name: Upload artifacts
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: detox-artifacts
          path: artifacts/
```

## Best Practices

- **Use testIDs consistently** - easier to maintain than text selectors
- **Wait for elements** - don't use arbitrary timeouts
- **Isolate tests** - each test should be independent
- **Test critical paths first** - login, checkout, core features
- **Run on real devices** periodically - simulators miss real issues

## Common Pitfalls

- Flaky tests due to animations - disable or wait properly
- Not handling async operations - use waitFor/pumpAndSettle
- Testing on simulators only - some bugs only appear on real devices
- Too many E2E tests - keep focused on critical paths
