---
name: "flutter-firebase-setup"
description: "Do not hand-edit `google-services.json` or `GoogleService-Info.plist` — let the CLI generate `firebase_options.dart` so platforms stay in sync."
source_type: "skill"
source_file: "skills/flutter-firebase-setup.md"
---

# flutter-firebase-setup

Migrated from `skills/flutter-firebase-setup.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Firebase Setup

Core `firebase_core` wiring, FlutterFire CLI, and per-flavor configuration. This skill covers **setup only** — for product-specific patterns see:

- **Messaging / FCM** — `mobile-push-notifications` agent
- **Crashlytics, Analytics, Remote Config** — pub.dev package docs (they drop onto an initialized app without ceremony)

## One-time project setup with FlutterFire CLI

Do not hand-edit `google-services.json` or `GoogleService-Info.plist` — let the CLI generate `firebase_options.dart` so platforms stay in sync.

```bash
# 1. Authenticate
dart pub global activate flutterfire_cli
firebase login

# 2. From the Flutter project root
flutterfire configure \
  --project=my-app-prod \
  --platforms=android,ios \
  --android-package-name=com.example.myapp \
  --ios-bundle-id=com.example.myapp \
  --out=lib/firebase_options.dart
```

This writes:

- `lib/firebase_options.dart` — platform-switched `FirebaseOptions`
- `android/app/google-services.json` (Android)
- `ios/Runner/GoogleService-Info.plist` (iOS) — registered in the Xcode project

## Initializing in `main()`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

`WidgetsFlutterBinding.ensureInitialized()` must run before `Firebase.initializeApp`. A synchronous crash here usually means a missing platform config file.

## Per-flavor configuration (dev / staging / prod)

Treat each environment as a separate Firebase project so dev traffic never lands in production Crashlytics / Analytics.

```bash
# Dev
flutterfire configure \
  --project=my-app-dev \
  --out=lib/firebase_options_dev.dart \
  --ios-bundle-id=com.example.myapp.dev \
  --android-package-name=com.example.myapp.dev

# Prod
flutterfire configure \
  --project=my-app-prod \
  --out=lib/firebase_options_prod.dart \
  --ios-bundle-id=com.example.myapp \
  --android-package-name=com.example.myapp
```

### Android — source-set per flavor

```gradle
// android/app/build.gradle
android {
  flavorDimensions "env"
  productFlavors {
    dev    { dimension "env"; applicationIdSuffix ".dev"     }
    prod   { dimension "env" }
  }
}
```

Place `google-services.json` under `android/app/src/dev/` and `android/app/src/prod/` so Gradle picks the correct one per flavor. Commit only the dev file; prod usually comes from a secret manager at build time.

### iOS — build-phase script

Ship `GoogleService-Info-dev.plist` and `GoogleService-Info-prod.plist` in the repo (or inject the prod one at CI time) and add a Run Script phase before "Copy Bundle Resources":

```bash
case "$CONFIGURATION" in
  *Dev*)  cp "$SRCROOT/Runner/GoogleService-Info-dev.plist"  "$SRCROOT/Runner/GoogleService-Info.plist" ;;
  *Prod*) cp "$SRCROOT/Runner/GoogleService-Info-prod.plist" "$SRCROOT/Runner/GoogleService-Info.plist" ;;
esac
```

### Dart entrypoint per flavor

```dart
// lib/main_dev.dart
import 'firebase_options_dev.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// Run with:
// flutter run -t lib/main_dev.dart --flavor dev
```

See the `flutter-flavors` skill for Gradle/Xcode wiring details shared with non-Firebase flavor setup.

## Should `firebase_options.dart` be committed?

**Commit it.** It contains API keys that are safe to expose — Firebase keys are public-by-design; access is gated server-side by App Check, Firestore Rules, and Auth. The official FlutterFire guidance is to check the file in. What matters is not the key but what's protecting the backend.

Do **not** commit: service-account JSON, Admin SDK credentials, `.env` files with non-Firebase secrets.

## App Check

App Check lets backend services (Firestore, Storage, Functions) verify the call came from your real app, not from a stolen API key.

```yaml
# pubspec.yaml
dependencies:
  firebase_app_check: ^0.3.1+4
```

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  runApp(const MyApp());
}
```

During development, run the app once in debug mode, copy the debug token printed to logcat/Xcode console, and register it in the Firebase Console under App Check → Apps → Manage debug tokens. Without this, debug builds will fail App Check checks against Firestore/Storage.

Production providers:
- **Android** — Play Integrity (requires Play Store distribution). For internal/APK distribution, fall back to `SafetyNet` (deprecated) or accept App Check-off for those channels.
- **iOS** — DeviceCheck (works out of the box) or App Attest (iOS 14+, more robust).

## Adding additional Firebase products

`Firebase.initializeApp` is enough for every FlutterFire package. Adding a new product is pubspec + native config:

```bash
# 1. Add the package
flutter pub add firebase_messaging firebase_crashlytics firebase_analytics

# 2. Re-run configure so the CLI re-registers any new platform hooks
flutterfire configure
```

No further `initializeApp` call is needed — products read from the already-initialized default app.

## Testing Firebase in unit tests

Mock the underlying method channels rather than the high-level API. The easiest route is to extract Firebase calls behind a repository interface and inject a fake in tests:

```dart
abstract class AnalyticsPort {
  Future<void> logEvent(String name, {Map<String, Object>? params});
}

class FirebaseAnalyticsAdapter implements AnalyticsPort {
  FirebaseAnalyticsAdapter(this._analytics);
  final FirebaseAnalytics _analytics;
  @override
  Future<void> logEvent(String name, {Map<String, Object>? params}) =>
      _analytics.logEvent(name: name, parameters: params);
}

class FakeAnalytics implements AnalyticsPort {
  final events = <(String, Map<String, Object>?)>[];
  @override
  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    events.add((name, params));
  }
}
```

For widget tests that must run against a real `FirebaseApp`, call `setupFirebaseAuthMocks()` / `setupFirebaseCoreMocks()` from `firebase_core_platform_interface/test.dart` in `setUpAll`.

## Common Pitfalls

- **`[core/no-app] No Firebase App '[DEFAULT]' has been created`** — `initializeApp` was not awaited, or ran before `ensureInitialized()`
- **Android build fails with `File google-services.json is missing`** — wrong source-set path for the active flavor; file must be under `android/app/src/<flavor>/`
- **iOS release build can't find `GoogleService-Info.plist`** — the build-phase script didn't run before "Copy Bundle Resources", or the file was listed in `.gitignore` but never injected at CI
- **App Check blocks all debug traffic** — debug token not registered in Firebase Console
- **Dev traffic polluting prod Analytics** — flavors share one Firebase project; split them
- **Hand-editing `firebase_options.dart`** — regenerates on every `flutterfire configure`; put overrides in a flavor-specific file instead
- **Committing Admin SDK JSON** — that *is* a secret; `firebase_options.dart` is not
