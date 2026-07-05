---
name: "crash-reporting"
description: "Setting up crash reporting and analysis."
source_type: "skill"
source_file: "skills/crash-reporting.md"
---

# crash-reporting

Migrated from `skills/crash-reporting.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Crash Reporting

Setting up crash reporting and analysis.

## Firebase Crashlytics

```typescript
// React Native setup
import crashlytics from '@react-native-firebase/crashlytics'

// Log non-fatal errors
crashlytics().recordError(error)

// Add custom keys
crashlytics().setAttribute('user_id', userId)
crashlytics().setAttributes({
  screen: 'Home',
  action: 'button_press',
})

// Log breadcrumbs
crashlytics().log('User clicked checkout')

// Force crash for testing
crashlytics().crash()
```

## Sentry Integration

```typescript
import * as Sentry from '@sentry/react-native'

Sentry.init({
  dsn: 'YOUR_DSN',
  environment: __DEV__ ? 'development' : 'production',
  tracesSampleRate: 0.2,
})

// Capture exception
Sentry.captureException(error)

// Add context
Sentry.setUser({ id: userId, email })
Sentry.setTag('feature', 'checkout')

// Breadcrumbs
Sentry.addBreadcrumb({
  category: 'navigation',
  message: 'Navigated to checkout',
  level: 'info',
})
```

## iOS Symbolication

```bash
# Upload dSYMs to Crashlytics
# ios/Podfile
post_install do |installer|
  # ... other config
end

# Manual upload
firebase crashlytics:symbols:upload --app=APP_ID ./ios/build/*.dSYM

# Sentry
sentry-cli upload-dif --org=ORG --project=PROJECT ./ios/build
```

## Android Mapping Files

```groovy
// android/app/build.gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            // Upload mapping file automatically
            firebaseCrashlytics {
                mappingFileUploadEnabled true
            }
        }
    }
}
```

## Flutter Crashlytics

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Catch Flutter errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(MyApp());
}
```

## Best Practices

- Upload symbols/mapping files in CI/CD
- Add meaningful breadcrumbs
- Set user context for debugging
- Monitor crash-free rate trends
