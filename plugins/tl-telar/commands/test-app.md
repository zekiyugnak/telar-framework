---
id: test-app
name: Test App
description: Comprehensive testing workflow including unit, integration, E2E, and device testing
category: command
usage: /tl-telar:test-app [scope]
example: /tl-telar:test-app full suite
phases:
  - name: Unit Tests
    progress: 0-25%
  - name: Integration Tests
    progress: 25-50%
  - name: E2E Tests
    progress: 50-75%
  - name: Device Testing
    progress: 75-90%
  - name: Report
    progress: 90-100%
---

# Test App

Comprehensive mobile app testing workflow.

## Phase 1: Unit Tests (0-25%)

### Load Agents
```yaml
agents:
  - mobile-unit-testing-expert
```

### Load Skills
```yaml
skills:
  - testing-pyramid-mobile
  - mock-strategies
```

### Test Categories
1. **Utility functions**
   - Data transformations
   - Validation logic
   - Formatters

2. **Custom hooks**
   - State management hooks
   - API hooks
   - Effect hooks

3. **Business logic**
   - State reducers
   - Computed values
   - Business rules

### Run Unit Tests
```bash
# React Native
yarn test --coverage

# Flutter
flutter test --coverage
```

### Coverage Targets
```markdown
| Category | Target | Current |
|----------|--------|---------|
| Utils | 90% | - |
| Hooks | 80% | - |
| Components | 70% | - |
| Overall | 75% | - |
```

### Debugging Failing Tests
When tests fail or are flaky:
```yaml
skills:
  - systematic-debugging    # Root cause before fix
```
- Do NOT immediately modify test code or production code
- Follow the 4-phase debugging process: investigate root cause → analyze patterns → form hypothesis → implement targeted fix
- For flaky tests: reproduce the flake, check for timing dependencies, async issues, or shared state

### Output
- Unit test results
- Coverage report
- Gaps identified

## Phase 2: Integration Tests (25-50%)

### Load Skills
```yaml
skills:
  - snapshot-testing
  - mock-strategies
```

### Test Categories
1. **Component rendering**
   - Props variations
   - State changes
   - User interactions

2. **Navigation flows**
   - Screen transitions
   - Deep link handling
   - Back navigation

3. **API integration**
   - Request/response handling
   - Error states
   - Loading states

### React Native Example
```typescript
import { render, fireEvent, waitFor } from '@testing-library/react-native'

test('login flow', async () => {
  const { getByPlaceholderText, getByText } = render(<LoginScreen />)

  fireEvent.changeText(getByPlaceholderText('Email'), 'test@test.com')
  fireEvent.changeText(getByPlaceholderText('Password'), 'password')
  fireEvent.press(getByText('Login'))

  await waitFor(() => {
    expect(mockNavigate).toHaveBeenCalledWith('Home')
  })
})
```

### Flutter Example
```dart
testWidgets('login flow', (tester) async {
  await tester.pumpWidget(LoginScreen());

  await tester.enterText(find.byKey(Key('email')), 'test@test.com');
  await tester.enterText(find.byKey(Key('password')), 'password');
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();

  expect(find.byType(HomeScreen), findsOneWidget);
});
```

### Output
- Integration test results
- Component test coverage

## Phase 3: E2E Tests (50-75%)

### Load Agents
```yaml
agents:
  - mobile-e2e-testing-expert
```

### E2E Framework
Choose based on project:
- **Detox** - React Native focused
- **Maestro** - Cross-platform, YAML-based
- **Appium** - Traditional, cross-platform

### Critical User Flows
```markdown
1. Onboarding flow
2. Sign up / Sign in
3. Core feature happy path
4. Purchase flow (if applicable)
5. Settings and profile
6. Logout flow
```

### Detox Example
```typescript
describe('Auth Flow', () => {
  beforeEach(async () => {
    await device.reloadReactNative()
  })

  it('should login successfully', async () => {
    await element(by.id('email-input')).typeText('test@test.com')
    await element(by.id('password-input')).typeText('password')
    await element(by.id('login-button')).tap()

    await expect(element(by.id('home-screen'))).toBeVisible()
  })
})
```

### Maestro Example
```yaml
appId: com.myapp
---
- launchApp
- tapOn: "Login"
- inputText:
    id: "email-input"
    text: "test@test.com"
- inputText:
    id: "password-input"
    text: "password"
- tapOn: "Submit"
- assertVisible: "Welcome"
```

### Output
- E2E test results
- Screenshots/videos
- Failure analysis

## Phase 4: Device Testing (75-90%)

### Load Agents
```yaml
agents:
  - mobile-device-testing
```

### Device Matrix
```markdown
iOS:
- iPhone 15 Pro (iOS 17)
- iPhone 12 (iOS 16)
- iPhone SE (iOS 15)

Android:
- Pixel 8 (Android 14)
- Samsung S23 (Android 13)
- Budget device (Android 11)
```

### Cloud Testing
```bash
# Firebase Test Lab
gcloud firebase test android run \
  --app app.apk \
  --test test.apk \
  --device model=Pixel8,version=34

# AWS Device Farm
aws devicefarm schedule-run \
  --project-arn $PROJECT_ARN \
  --app-arn $APP_ARN \
  --test type=APPIUM_PYTHON
```

### Manual Testing Checklist
```markdown
- [ ] App installs correctly
- [ ] Permissions requested appropriately
- [ ] Orientation changes handled
- [ ] Background/foreground transitions
- [ ] Network interruption recovery
- [ ] Push notifications work
```

### Output
- Device test results
- Platform-specific issues
- Compatibility report

## Phase 5: Report (90-100%)

### Test Summary
```markdown
| Test Type | Passed | Failed | Skipped |
|-----------|--------|--------|---------|
| Unit | 145 | 2 | 3 |
| Integration | 38 | 1 | 0 |
| E2E | 12 | 0 | 1 |
| Device | 6/6 | 0 | 0 |
```

### Coverage Report
- Overall coverage percentage
- Uncovered critical paths
- Recommendations

### Issues Found
- Categorized by severity
- Reproduction steps
- Suggested fixes

### Output
- Complete test report
- Action items
- CI integration recommendations

## Completion Checklist

- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] E2E tests passing
- [ ] Device testing complete
- [ ] Coverage targets met
- [ ] Issues documented
- [ ] Report generated
