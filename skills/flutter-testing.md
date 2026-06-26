---
id: flutter-testing
category: skill
tags: [flutter-test, widget-testing, integration-testing, mockito, golden-tests]
capabilities:
  - Widget testing with flutter_test
  - Integration testing
  - Mocking with mocktail/mockito
  - Golden tests for visual regression
useWhen:
  - Setting up testing for Flutter apps
  - Writing widget tests
  - Creating visual regression tests
---

# Flutter Testing

Testing patterns for Flutter applications.

## Widget Testing

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter increments', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Login form validation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginForm()),
    );

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
  });
}
```

## Mocking with Mocktail

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  testWidgets('shows user name after login', (tester) async {
    when(() => mockAuthRepo.signIn(any(), any()))
        .thenAnswer((_) async => User(name: 'John'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepoProvider.overrideWithValue(mockAuthRepo)],
        child: const MyApp(),
      ),
    );

    await tester.enterText(find.byKey(Key('email')), 'test@test.com');
    await tester.enterText(find.byKey(Key('password')), 'password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome John'), findsOneWidget);
  });
}
```

## Golden Tests

```dart
testWidgets('Button renders correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppButton(label: 'Submit', onPressed: () {}),
      ),
    ),
  );

  await expectLater(
    find.byType(AppButton),
    matchesGoldenFile('goldens/button.png'),
  );
});
```

## Integration Testing

```dart
// integration_test/app_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full app flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Perform actions and verify
  });
}
```

## Best Practices

- Use find.byKey for reliable widget finding
- Mock external dependencies
- Update golden files when UI intentionally changes
- Test on CI with integration tests

## Flake Resistance (integration & E2E)

For `integration_test` / Patrol / Maestro flows, where flakiness is most costly:

- **No fixed delays** — never `await Future.delayed(...)` to "wait for" UI. Use `tester.pumpAndSettle()`, or pump until a specific finder matches.
- **Wait for elements, not time** — assert on `find.byKey`/`find.text` becoming present; avoid blanket settles that hide races.
- **Stable finders** — prefer `find.byKey` and semantic finders over widget-tree position.
- **Dynamic per-run data** — unique values per run (`'test-${DateTime.now().millisecondsSinceEpoch}'`) for parallel-safe, collision-free runs.
- **Isolation** — each test self-contained; no shared mutable state; credentials from env, never hardcoded.
- **Exit bar** — a new or changed integration/E2E test must pass **3+ consecutive headless runs** before it counts as done. See `verification-before-completion`.
