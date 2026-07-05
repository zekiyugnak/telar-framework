---
name: "flutter-flavors"
description: "Environment configuration with Flutter flavors."
source_type: "skill"
source_file: "skills/flutter-flavors.md"
---

# flutter-flavors

Migrated from `skills/flutter-flavors.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Build Flavors

Environment configuration with Flutter flavors.

## Flavor Setup

```dart
// lib/config/environment.dart
enum Environment { dev, staging, prod }

class AppConfig {
  final Environment environment;
  final String apiUrl;
  final String appName;

  static late AppConfig instance;

  AppConfig._({
    required this.environment,
    required this.apiUrl,
    required this.appName,
  });

  static void initialize(Environment env) {
    instance = switch (env) {
      Environment.dev => AppConfig._(
        environment: env,
        apiUrl: 'https://dev-api.myapp.com',
        appName: 'MyApp Dev',
      ),
      Environment.staging => AppConfig._(
        environment: env,
        apiUrl: 'https://staging-api.myapp.com',
        appName: 'MyApp Staging',
      ),
      Environment.prod => AppConfig._(
        environment: env,
        apiUrl: 'https://api.myapp.com',
        appName: 'MyApp',
      ),
    };
  }
}

// main_dev.dart
void main() {
  AppConfig.initialize(Environment.dev);
  runApp(const MyApp());
}
```

## Android Flavors

```groovy
// android/app/build.gradle
flavorDimensions "environment"
productFlavors {
  dev {
    dimension "environment"
    applicationIdSuffix ".dev"
    resValue "string", "app_name", "MyApp Dev"
  }
  staging {
    dimension "environment"
    applicationIdSuffix ".staging"
  }
  prod {
    dimension "environment"
  }
}
```

## iOS Schemes

Create separate schemes in Xcode:
- MyApp-Dev
- MyApp-Staging
- MyApp-Prod

Each with different bundle identifiers and configurations.

## Running Flavors

```bash
flutter run --flavor dev -t lib/main_dev.dart
flutter run --flavor prod -t lib/main_prod.dart

flutter build apk --flavor prod -t lib/main_prod.dart
flutter build ios --flavor prod -t lib/main_prod.dart
```

## Best Practices

- Use separate entry points per flavor
- Keep sensitive config out of code
- Test all flavors in CI
- Use consistent naming across platforms
