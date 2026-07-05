---
name: "test-app"
description: "Comprehensive testing workflow including unit, integration, E2E, and device testing"
source_type: "command"
source_file: "commands/test-app.md"
---

# test-app

Migrated from `commands/test-app.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:test-app`; invoke it as `$test-app` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


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
