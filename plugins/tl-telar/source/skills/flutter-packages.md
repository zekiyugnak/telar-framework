---
id: flutter-packages
category: skill
tags: [pub-dev, packages, plugins, dependencies, versioning]
capabilities:
  - Finding and evaluating packages
  - Popular package recommendations
  - Creating and publishing packages
  - Dependency management
useWhen:
  - Choosing Flutter packages
  - Managing dependencies
  - Creating reusable packages
---

# Flutter Packages

Essential packages and dependency management for Flutter.

## Essential Packages

```yaml
# pubspec.yaml
dependencies:
  # State Management
  flutter_riverpod: ^2.4.0
  # or flutter_bloc: ^8.1.0

  # Navigation
  go_router: ^13.0.0

  # Networking
  dio: ^5.4.0
  retrofit: ^4.0.0

  # Local Storage
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.0

  # UI
  flutter_svg: ^2.0.0
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0

  # Utils
  intl: ^0.18.0
  uuid: ^4.2.0
  url_launcher: ^6.2.0

dev_dependencies:
  # Code Generation
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  riverpod_generator: ^2.3.0

  # Testing
  mocktail: ^1.0.0

  # Linting
  flutter_lints: ^3.0.0
```

## Package Evaluation

```markdown
Criteria for choosing packages:
1. Popularity (likes, pub points)
2. Maintenance (recent updates)
3. Null safety support
4. Platform support (web, desktop)
5. Documentation quality
6. Issue response time
```

## Creating Packages

```bash
# Create package
flutter create --template=package my_package

# Create plugin (with native code)
flutter create --template=plugin --platforms=android,ios my_plugin
```

```yaml
# Package pubspec.yaml
name: my_package
description: A useful package
version: 1.0.0
repository: https://github.com/user/my_package

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter
```

## Publishing

```bash
# Dry run
flutter pub publish --dry-run

# Publish
flutter pub publish
```

## Best Practices

- Pin major versions (`^1.0.0`)
- Check package health on pub.dev
- Review changelog before updating
- Test major updates in a branch first
- Prefer well-maintained packages
