---
name: "ui-library-integration"
description: "Expert guidance on selecting, integrating, and customizing mobile UI component libraries for React Native and Flutter."
source_type: "skill"
source_file: "skills/ui-library-integration.md"
---

# ui-library-integration

Migrated from `skills/ui-library-integration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# UI Library Integration

Expert guidance on selecting, integrating, and customizing mobile UI component libraries for React Native and Flutter.

## Problem

Choosing the wrong UI library is expensive. Teams pick a library based on GitHub stars, then discover it does not support their theming requirements, performs poorly on low-end devices, or lacks accessibility features. Switching libraries mid-project means rewriting dozens of screens. Even after choosing correctly, integrating custom design tokens into a library's theme system requires deep knowledge of each library's architecture.

## Solution

### 1. React Native Library Decision Tree

```text
Start
  |
  +-- Need maximum performance & compile-time styles?
  |     YES --> Tamagui
  |     NO  --> continue
  |
  +-- Need Material Design 3 compliance?
  |     YES --> React Native Paper
  |     NO  --> continue
  |
  +-- Need headless/unstyled primitives for full design control?
  |     YES --> gluestack-ui
  |     NO  --> continue
  |
  +-- Need a quick prototype with sensible defaults?
  |     YES --> React Native Elements
  |     NO  --> Build custom components from scratch
```

### 2. Library Comparison Matrix

| Feature | Tamagui | gluestack-ui | RN Paper | RN Elements |
|---------|---------|-------------|----------|-------------|
| Styling approach | Compile-time | Runtime / NativeWind | Runtime | Runtime |
| Theme tokens | First-class | Via config | MD3 tokens | Override props |
| Tree shaking | Excellent | Good | Moderate | Moderate |
| Dark mode | Built-in | Built-in | Built-in | Manual |
| Accessibility | Good | Excellent | Excellent | Basic |
| Web support | Excellent | Good | Limited | Limited |
| Bundle impact | ~40KB | ~60KB | ~120KB | ~80KB |
| Learning curve | Steep | Moderate | Low | Low |

### 3. Tamagui Integration

```typescript
// tamagui.config.ts
import { createTamagui, createTokens } from 'tamagui';
import { semanticColors } from './design-tokens/colors';
import { typography } from './design-tokens/typography';

const tokens = createTokens({
  color: {
    primary: semanticColors.primary.light,
    primaryDark: semanticColors.primary.dark,
    background: semanticColors.background.light,
    backgroundDark: semanticColors.background.dark,
    surface: semanticColors.surface.light,
    surfaceDark: semanticColors.surface.dark,
    textPrimary: semanticColors.textPrimary.light,
    textPrimaryDark: semanticColors.textPrimary.dark,
    error: semanticColors.error.light,
    errorDark: semanticColors.error.dark,
  },
  space: { xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48 },
  size: { sm: 36, md: 44, lg: 56 },
  radius: { sm: 4, md: 8, lg: 16, full: 9999 },
});

const config = createTamagui({
  tokens,
  themes: {
    light: {
      background: tokens.color.background,
      color: tokens.color.textPrimary,
      primary: tokens.color.primary,
    },
    dark: {
      background: tokens.color.backgroundDark,
      color: tokens.color.textPrimaryDark,
      primary: tokens.color.primaryDark,
    },
  },
});

export default config;
```

### 4. gluestack-ui Integration

```typescript
// gluestack-ui.config.ts
import { createConfig } from '@gluestack-ui/themed';
import { semanticColors } from './design-tokens/colors';

export const config = createConfig({
  aliases: {
    bg: 'backgroundColor',
    p: 'padding',
    m: 'margin',
    rounded: 'borderRadius',
  },
  tokens: {
    colors: {
      primary500: semanticColors.primary.light,
      primary600: semanticColors.primary.dark,
      backgroundLight: semanticColors.background.light,
      backgroundDark: semanticColors.background.dark,
      textLight: semanticColors.textPrimary.light,
      textDark: semanticColors.textPrimary.dark,
      error500: semanticColors.error.light,
    },
    space: { '1': 4, '2': 8, '3': 12, '4': 16, '5': 20, '6': 24, '8': 32 },
    radii: { sm: 4, md: 8, lg: 16, full: 9999 },
  },
});
```

### 5. React Native Paper Integration

```typescript
// theme.ts
import { MD3LightTheme, MD3DarkTheme, configureFonts } from 'react-native-paper';
import { semanticColors } from './design-tokens/colors';

const fontConfig = {
  displayLarge:  { fontFamily: 'System', fontSize: 34, fontWeight: '700' as const },
  titleLarge:    { fontFamily: 'System', fontSize: 22, fontWeight: '700' as const },
  bodyLarge:     { fontFamily: 'System', fontSize: 17, fontWeight: '400' as const },
  labelLarge:    { fontFamily: 'System', fontSize: 15, fontWeight: '600' as const },
};

export const lightTheme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    primary: semanticColors.primary.light,
    background: semanticColors.background.light,
    surface: semanticColors.surface.light,
    error: semanticColors.error.light,
    onPrimary: '#FFFFFF',
    onBackground: semanticColors.textPrimary.light,
    onSurface: semanticColors.textPrimary.light,
  },
  fonts: configureFonts({ config: fontConfig }),
};

export const darkTheme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    primary: semanticColors.primary.dark,
    background: semanticColors.background.dark,
    surface: semanticColors.surface.dark,
    error: semanticColors.error.dark,
    onPrimary: '#FFFFFF',
    onBackground: semanticColors.textPrimary.dark,
    onSurface: semanticColors.textPrimary.dark,
  },
  fonts: configureFonts({ config: fontConfig }),
};
```

### 6. Flutter Library Decision Tree

```text
Start
  |
  +-- Building for Material Design 3 (Android-first)?
  |     YES --> Material 3 (built-in)
  |     NO  --> continue
  |
  +-- Building iOS-first or need iOS-native look?
  |     YES --> CupertinoTheme + cupertino_icons
  |     NO  --> continue
  |
  +-- Need adaptive UI that auto-switches per platform?
  |     YES --> flutter_adaptive_scaffold + Platform checks
  |     NO  --> continue
  |
  +-- Need a comprehensive pre-built component set?
        YES --> Material 3 with custom ThemeData
        NO  --> Build custom widgets
```

### 7. Flutter ThemeData Integration

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../design/tokens.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.lightPrimary,
      surface: AppColors.lightSurface,
      error: AppColors.lightError,
      onPrimary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    dividerColor: AppColors.lightBorder,
    textTheme: _textTheme(AppColors.lightTextPrimary),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkPrimary,
      surface: AppColors.darkSurface,
      error: AppColors.darkError,
      onPrimary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    dividerColor: AppColors.darkBorder,
    textTheme: _textTheme(AppColors.darkTextPrimary),
  );

  static TextTheme _textTheme(Color color) => TextTheme(
    displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: color),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
    bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: color),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
  );
}
```

## Why This Works

The decision tree eliminates analysis paralysis by matching project requirements to library capabilities. The integration templates show exactly how to wire design tokens into each library's theme system, so teams can adopt a library without guessing at configuration. The comparison matrix provides the hard data (bundle size, accessibility, web support) that GitHub stars do not capture.

## Edge Cases

- **Multiple libraries**: some teams use RN Paper for form inputs alongside a custom component set; document the boundary clearly
- **Library version upgrades**: pin major versions and test theme integration after each upgrade; API surfaces change significantly between majors
- **Server-side rendering**: if targeting web via React Native Web, verify that the chosen library supports SSR/SSG
- **Expo compatibility**: some libraries require native module linking; verify compatibility with Expo managed workflow before committing
- **RTL support**: test theme and component behavior with RTL locales; not all libraries handle RTL mirroring correctly

## Verification

1. **Theme consistency**: render a screen using only library components and verify colors match the design token table
2. **Dark mode**: toggle system appearance and confirm all library components switch correctly
3. **Bundle analysis**: run the platform bundler's size analysis and confirm the library does not exceed expected impact
4. **Accessibility audit**: run a screen reader over library components and confirm labels, roles, and focus order are correct
5. **Performance**: measure FPS during scroll and transition animations on a low-end device

## References

- Tamagui: https://tamagui.dev
- gluestack-ui: https://gluestack.io
- React Native Paper: https://callstack.github.io/react-native-paper/
- React Native Elements: https://reactnativeelements.com
- Flutter Material 3: https://docs.flutter.dev/ui/design/material
- flutter_adaptive_scaffold: https://pub.dev/packages/flutter_adaptive_scaffold
