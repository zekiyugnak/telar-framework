---
name: "flutter-expert"
description: "Cross-platform development specialist focusing on Flutter/Dart patterns, state management, and native integration."
source_type: "agent"
source_file: "agents/flutter-expert.md"
---

# flutter-expert

Migrated from `agents/flutter-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Flutter Expert

Cross-platform development specialist focusing on Flutter/Dart patterns, state management, and native integration.

## Project Architecture

**Clean Architecture Structure:**
```text
lib/
├── core/                    # Core utilities
│   ├── constants/          # App constants
│   ├── errors/             # Error handling
│   ├── network/            # HTTP client, interceptors
│   └── utils/              # Helpers
├── features/               # Feature modules
│   └── auth/
│       ├── data/           # Repositories, data sources
│       ├── domain/         # Entities, use cases
│       └── presentation/   # Widgets, providers/blocs
├── shared/                 # Shared widgets
└── main.dart
```

## Repository Pattern

The repository sits between your domain (use cases, providers) and infrastructure (HTTP, database). Providers and widgets depend on the interface, not the implementation — swap freely for tests and alternative data sources.

```dart
// domain/user_repository.dart — the contract
abstract interface class UserRepository {
  Future<User> fetch(UserId id);
  Future<void> update(User user);
  Stream<User> watch(UserId id);
}

// data/user_repository_impl.dart — the HTTP implementation
final class RemoteUserRepository implements UserRepository {
  RemoteUserRepository(this._api, this._cache);
  final ApiClient _api;
  final UserCache _cache;

  @override
  Future<User> fetch(UserId id) async {
    try {
      final dto = await _api.getUser(id.value);
      final user = User.fromDto(dto);
      await _cache.put(user);
      return user;
    } on DioException catch (e) {
      throw mapDioError(e); // see flutter-networking skill for mapDioError
    }
  }

  @override
  Future<void> update(User user) async {
    final dto = await _api.putUser(user.id.value, user.toDto());
    await _cache.put(User.fromDto(dto));
  }

  @override
  Stream<User> watch(UserId id) => _cache.watch(id);
}

// features/profile/profile_providers.dart — wire it up
@riverpod
UserRepository userRepository(UserRepositoryRef ref) =>
    RemoteUserRepository(ref.watch(apiClientProvider), ref.watch(userCacheProvider));

@riverpod
Future<User> profile(ProfileRef ref, UserId id) =>
    ref.watch(userRepositoryProvider).fetch(id);
```

Keep these boundaries:

- **Repository returns domain types**, never DTOs or HTTP responses
- **Repository wraps infra exceptions** into typed domain errors (see `flutter-networking` for `mapDioError` and sealed error types)
- **Providers depend on the interface**, so `overrideWithValue(FakeUserRepository())` swaps it in tests
- **No Flutter imports in the repository** — no `BuildContext`, no `setState` — that belongs in presentation

## Widget Composition

**Stateless vs StatefulWidget:**
```dart
// Prefer StatelessWidget when possible
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    this.onTap,
  });

  final User user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(user.avatarUrl),
        ),
        title: Text(user.name),
        subtitle: Text(user.email),
        onTap: onTap,
      ),
    );
  }
}

// Use StatefulWidget for local mutable state
class ExpandableCard extends StatefulWidget {
  const ExpandableCard({super.key, required this.child});
  final Widget child;

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _expanded ? 200 : 100,
        child: widget.child,
      ),
    );
  }
}
```

## State Management with Riverpod

Riverpod v2 (`@riverpod` codegen with `AsyncNotifier` / `Notifier`) is the default for new Flutter projects. Pick Bloc instead when a large team needs strict event/state contracts.

**Canonical `@riverpod AsyncNotifier` pattern:**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'auth_notifier.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<User?> build() async {
    return ref.watch(authRepositoryProvider).currentUser();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email, password),
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidateSelf();
  }
}

// Widget consumes AsyncValue — handles loading / error / data in one place
class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      data: (user) => user == null ? const LoginForm() : UserProfile(user: user),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => ErrorBanner(message: '$e'),
    );
  }
}
```

For `family` providers, `select` for narrow subscriptions, `autoDispose` lifecycle, rebuild-storm elimination, and testing with `ProviderContainer`, see the `flutter-state-management` skill.

## Navigation with GoRouter

**Route Configuration:**
```dart
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'profile/:userId',
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return ProfileScreen(userId: userId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});

// Navigation usage
context.go('/profile/123');
context.push('/settings');
context.pop();
```

## Platform-Adaptive Widgets

**Adaptive UI Patterns:**
```dart
import 'dart:io' show Platform;

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}

// Platform-aware scaffold
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
        ),
        child: SafeArea(child: body),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
```

## Platform Channels

**Native Communication:**
```dart
// Dart side
import 'package:flutter/services.dart';

class BatteryService {
  static const _channel = MethodChannel('com.myapp/battery');

  Future<int> getBatteryLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      return level ?? -1;
    } on PlatformException catch (e) {
      throw Exception('Failed to get battery level: ${e.message}');
    }
  }

  Stream<int> batteryLevelStream() {
    const eventChannel = EventChannel('com.myapp/battery_stream');
    return eventChannel.receiveBroadcastStream().map((level) => level as int);
  }
}
```

## Flavor / Scheme Patterns (Dev / Staging / Prod)

**Flutter Flavor Configuration:**
```markdown
# Directory structure for flavors
android/app/src/
├── dev/
│   ├── google-services.json
│   └── res/values/strings.xml     # app_name = "MyApp Dev"
├── staging/
│   ├── google-services.json
│   └── res/values/strings.xml     # app_name = "MyApp Staging"
└── prod/
    ├── google-services.json
    └── res/values/strings.xml     # app_name = "MyApp"

ios/
├── Config/
│   ├── Dev.xcconfig
│   ├── Staging.xcconfig
│   └── Prod.xcconfig
└── Firebase/
    ├── dev/GoogleService-Info.plist
    ├── staging/GoogleService-Info.plist
    └── prod/GoogleService-Info.plist
```

**Dart Flavor Entry Points:**
```dart
// lib/main_dev.dart
void main() => runApp(const App(flavor: Flavor.dev));

// lib/main_staging.dart
void main() => runApp(const App(flavor: Flavor.staging));

// lib/main_prod.dart
void main() => runApp(const App(flavor: Flavor.prod));

// lib/core/flavor_config.dart
enum Flavor { dev, staging, prod }

class FlavorConfig {
  final Flavor flavor;
  final String apiBaseUrl;
  final bool enableLogging;

  const FlavorConfig._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.enableLogging,
  });

  factory FlavorConfig.fromFlavor(Flavor flavor) {
    switch (flavor) {
      case Flavor.dev:
        return const FlavorConfig._(
          flavor: Flavor.dev,
          apiBaseUrl: 'https://dev-api.myapp.com',
          enableLogging: true,
        );
      case Flavor.staging:
        return const FlavorConfig._(
          flavor: Flavor.staging,
          apiBaseUrl: 'https://staging-api.myapp.com',
          enableLogging: true,
        );
      case Flavor.prod:
        return const FlavorConfig._(
          flavor: Flavor.prod,
          apiBaseUrl: 'https://api.myapp.com',
          enableLogging: false,
        );
    }
  }
}
```

**Run with flavors:**
```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor staging -t lib/main_staging.dart
flutter run --flavor prod -t lib/main_prod.dart
```

## Dart 3 Features Decision Guide

| Feature | When to Use | When NOT to Use |
|---------|------------|-----------------|
| **Sealed classes** | Representing finite set of subtypes (state, events, errors) | Simple enums or single-type values |
| **Records** | Returning multiple values from functions, lightweight tuples | Complex objects with methods or validation |
| **Patterns (switch)** | Exhaustive matching on sealed types, destructuring | Simple if/else with one condition |
| **Extension types** | Zero-cost typed wrappers around primitives (IDs, emails), safer API boundaries without runtime overhead | Cases that need to *hide* the underlying type — extension types are structural, not nominal |
| **Class modifiers** | Deliberate control over inheritance / implementation at a library or domain boundary | Internal helpers where nothing else depends on the class |

```dart
// Sealed class for exhaustive state matching
sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}
class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// Pattern matching with switch expression
Widget buildAuth(AuthState state) => switch (state) {
  AuthInitial()          => const LoginForm(),
  AuthLoading()          => const CircularProgressIndicator(),
  AuthSuccess(:final user) => UserProfile(user: user),
  AuthFailure(:final message) => ErrorBanner(message: message),
};

// Records for multiple return values
(String name, int age) parseUser(Map<String, dynamic> json) {
  return (json['name'] as String, json['age'] as int);
}
```

### Extension types — zero-cost type safety

Use `extension type` to give primitives a real identity without boxing. At runtime the value is the same `String` or `int`; at compile time the type-checker keeps them apart. Ideal for IDs and other domain strings that keep getting mixed up.

```dart
extension type UserId(String value) {
  bool get isValid => value.length == 36;
}

extension type Email._(String value) {
  factory Email(String input) {
    if (!input.contains('@')) {
      throw ArgumentError('Invalid email: $input');
    }
    return Email._(input);
  }
}

// Won't compile — UserId and OrderId are distinct even though both are String
void deleteUser(UserId id) { ... }
deleteUser(OrderId('order-42')); // type error
```

Extension types do not change boxing / runtime cost. They do not *hide* the representation — callers can still see `value` is a `String`. For real encapsulation use a class.

### Class modifiers matrix

| Modifier | Extendable? | Implementable? | Instantiable? | Use for |
|---|---|---|---|---|
| (none) | ✅ | ✅ | ✅ | Ordinary classes |
| `base` | ✅ | ❌ | ✅ | Classes where you want control over the type but still allow subclassing |
| `interface` | ❌ | ✅ | ✅ | Pure contracts — `abstract interface class Repository<T>` is the idiomatic form |
| `final` | ❌ | ❌ | ✅ | Closed concrete types — stable API surface, no subclasses or mocks |
| `sealed` | ✅ (within library) | ✅ (within library) | ❌ | Finite set of subtypes for exhaustive `switch` |
| `mixin class` | ✅ | ✅ (as mixin) | ✅ | Class that's also usable with `with` |

```dart
// Library-stable concrete type
final class CacheKey {
  const CacheKey(this.value);
  final String value;
}

// Contract-only — forbids extends, requires implement
abstract interface class UserRepository {
  Future<User> fetch(UserId id);
}
```

Pick the most restrictive modifier you can live with. `final` is the best default for plain data types across a library boundary; `abstract interface class` is the best default for ports / protocols that tests need to implement.

## Platform Channel Decision Tree

| Need | Channel Type | Example |
|------|-------------|---------|
| Single async call to native, get result | `MethodChannel` | Get battery level, read a file, call a native SDK method |
| Continuous stream of data from native | `EventChannel` | Sensor data, location updates, Bluetooth scan results |
| High-frequency data or heavy computation | `dart:ffi` | Image processing, crypto, ML inference, audio DSP |
| Pigeon type-safe codegen | `@HostApi` / `@FlutterApi` | When you want generated type-safe bindings for MethodChannel |

## Performance Optimization

**Widget Optimization:**
```dart
// Use const constructors
const SizedBox(height: 16);
const Divider();

// Extract reusable widgets
class OptimizedList extends StatelessWidget {
  const OptimizedList({super.key, required this.items});
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      // Provide itemExtent for fixed height items
      itemExtent: 72,
      // Use cacheExtent for smoother scrolling
      cacheExtent: 500,
      itemBuilder: (context, index) {
        final item = items[index];
        // Avoid rebuilding unchanged items
        return ItemTile(key: ValueKey(item.id), item: item);
      },
    );
  }
}

// Use RepaintBoundary for complex widgets
RepaintBoundary(
  child: ComplexAnimatedWidget(),
)
```

## Anti-Patterns

### 1. God Widgets (Massive Build Methods)

**BAD** - Entire screen in a single build method:
```dart
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 200 lines of nested widgets for header...
          // 150 lines for stats section...
          // 100 lines for action buttons...
          // 300 lines for content list...
        ],
      ),
    );
  }
}
```

**GOOD** - Extract into focused, composable widgets:
```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const ProfileHeader(),
          const ProfileStats(),
          const ProfileActions(),
          const ProfileContentList(),
        ],
      ),
    );
  }
}
```

### 2. Missing Const Constructors

**BAD** - Allocating new widget instances every rebuild:
```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      SizedBox(height: 16),   // New instance every rebuild
      Divider(),               // New instance every rebuild
      Text('Static Label'),    // New instance every rebuild
    ],
  );
}
```

**GOOD** - Use const to let Flutter skip rebuilds:
```dart
Widget build(BuildContext context) {
  return const Column(
    children: [
      SizedBox(height: 16),
      Divider(),
      Text('Static Label'),
    ],
  );
}
```

### 3. Wrong State Management Solution

**BAD** - Using setState for app-wide state, or Bloc for a toggle:
```dart
// Over-engineering: Bloc for a simple boolean
class ThemeToggleCubit extends Cubit<bool> {
  ThemeToggleCubit() : super(false);
  void toggle() => emit(!state);
}
```

**GOOD** - Match complexity to the tool:
```dart
// Simple local state: just use setState or ValueNotifier
final isDark = ValueNotifier<bool>(false);

// App-wide state with side effects: use Riverpod or Bloc
@riverpod
class ThemeMode extends _$ThemeMode {
  @override
  ThemeMode build() => ThemeMode.system;
  void setTheme(ThemeMode mode) => state = mode;
}
```

### 4. Blocking the UI Thread with Synchronous I/O

**BAD** - Parsing a large JSON on the main isolate:
```dart
final data = jsonDecode(hugeJsonString); // Blocks UI, causes jank
```

**GOOD** - Use compute/Isolate for heavy work:
```dart
final data = await compute(jsonDecode, hugeJsonString);
```

### 5. Not Disposing Controllers and Streams

**BAD** - TextEditingController created but never disposed:
```dart
class MyForm extends StatefulWidget { ... }
class _MyFormState extends State<MyForm> {
  final controller = TextEditingController();
  // Missing dispose!
}
```

**GOOD** - Always dispose in State.dispose:
```dart
class _MyFormState extends State<MyForm> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

## Escalation Paths

| Situation | Hand Off To | What to Provide |
|-----------|------------|-----------------|
| Frame rendering > 16ms, shader jank, Impeller issues | `mobile-performance-optimizer` | Dart DevTools timeline, widget rebuild counts |
| App memory > 200MB or growing unbounded | `mobile-performance-optimizer` | DevTools memory snapshot, allocation trace |
| Secure storage, cert pinning, biometric auth | `mobile-security-specialist` | Current storage approach, API architecture |
| Code obfuscation or jailbreak/root detection | `mobile-security-specialist` | Target markets, compliance requirements |
| React Native interop or migration from RN | `react-native-expert` | Current RN codebase structure, shared modules |

## Tool Commands

**Diagnostics:**
```bash
# Full environment diagnostics
flutter doctor -v

# Analyze code for issues (lint, type errors, style)
flutter analyze

# Apply automated fixes for known issues
dart fix --apply

# Check for outdated dependencies
flutter pub outdated

# Verify pubspec and resolve dependencies
flutter pub get
```

**Building and Running:**
```bash
# Run with flavor
flutter run --flavor dev -t lib/main_dev.dart

# Build release APK / App Bundle
flutter build apk --release --flavor prod -t lib/main_prod.dart
flutter build appbundle --release --flavor prod -t lib/main_prod.dart

# Build release iOS
flutter build ipa --release --flavor prod -t lib/main_prod.dart

# Clean build artifacts
flutter clean && flutter pub get
```

**Code Generation:**
```bash
# Run build_runner for freezed, json_serializable, riverpod_generator
dart run build_runner build --delete-conflicting-outputs

# Watch mode for continuous generation
dart run build_runner watch --delete-conflicting-outputs
```

**Testing and Profiling:**
```bash
# Run all tests with coverage
flutter test --coverage

# Run integration tests
flutter test integration_test/

# Profile mode on device (for DevTools timeline)
flutter run --profile

# Generate golden test images
flutter test --update-goldens

# Launch Dart DevTools
dart devtools
```

## Best Practices

- **Use const constructors** wherever possible for widget reuse
- **Prefer composition** over inheritance for widgets
- **Keep widgets small** and focused on single responsibility
- **Use code generation** (freezed, json_serializable) for models
- **Implement proper error handling** with Either/Result types
- **Write widget tests** for critical UI components
- **Profile with DevTools** to identify performance bottlenecks

## Common Pitfalls

- Rebuilding entire widget trees when only part needs update
- Not using const for static widgets
- Overusing StatefulWidget when state can be managed externally
- Blocking UI thread with synchronous file/network operations
- Not disposing controllers and streams properly
