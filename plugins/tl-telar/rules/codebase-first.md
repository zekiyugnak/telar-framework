# Codebase First Rule

Always explore the existing project before generating any code. This prevents architecture conflicts, duplicate implementations, and style inconsistencies.

## DO

- **Read project config first**: `package.json` / `pubspec.yaml` to identify framework, dependencies, and scripts
- **Check existing navigation**: look for React Navigation setup, GoRouter config, or auto_route setup before adding routes
- **Identify state management**: check for Zustand stores, Redux slices, Riverpod providers, BLoC classes before adding state
- **Scan for design tokens**: look for theme files, color constants, spacing scales, typography definitions
- **Check existing component library**: search for shared UI components before creating new ones
- **Match existing code style**: observe naming conventions (camelCase vs snake_case), file organization, import patterns
- **Read existing tests**: understand test patterns, mocking strategies, and test file locations before writing new tests
- **Check for existing utilities**: search for helpers, hooks, or extensions that already solve your problem

## DON'T

- **Don't generate code that conflicts with existing architecture** — if the project uses feature-based folders, don't create layer-based folders
- **Don't suggest a different state management library** than what's already installed — if the project uses Zustand, don't add Redux
- **Don't ignore existing navigation patterns** — if the project uses tab navigation, don't add a drawer without checking the nav structure
- **Don't create duplicate components** — if `Button.tsx` exists in `src/components/`, use it instead of creating a new one
- **Don't use different styling approaches** — if the project uses StyleSheet, don't introduce styled-components; if it uses ThemeData, don't use raw colors
- **Don't ignore TypeScript/Dart strictness** — match the existing strict mode, null safety, and lint rules

## Exploration Checklist

Before writing any implementation code, confirm:

```markdown
- [ ] Project type identified (React Native / Flutter / Expo)
- [ ] package.json or pubspec.yaml read
- [ ] Navigation library and pattern understood
- [ ] State management approach identified
- [ ] Existing component library scanned
- [ ] Design tokens / theme file located
- [ ] Test patterns observed
- [ ] Code style conventions noted
```

## Quick Detection Commands

```bash
# React Native / Expo
cat package.json | grep -E "react-native|expo|navigation|zustand|redux|mobx"

# Flutter
cat pubspec.yaml | grep -E "flutter|go_router|auto_route|riverpod|bloc|provider"

# Project structure
ls src/ || ls lib/
```

This rule is enforced by the `explore-before-generate` hook and referenced by `brainstorm-first` and `plan-and-track` skills.
