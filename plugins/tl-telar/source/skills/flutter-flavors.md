---
id: flutter-flavors
category: skill
tags: [flavors, environments, build-configuration, conditional-compilation]
capabilities:
  - Flutter flavors for environments
  - Build configuration management
  - Environment variables
  - Conditional compilation
useWhen:
  - Setting up dev/staging/prod environments
  - Configuring different app variants
  - Managing environment-specific settings
---

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
