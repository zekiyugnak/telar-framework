---
name: "flutter-packages"
description: "Essential packages and dependency management for Flutter."
source_type: "skill"
source_file: "skills/flutter-packages.md"
---

# flutter-packages

Migrated from `skills/flutter-packages.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
