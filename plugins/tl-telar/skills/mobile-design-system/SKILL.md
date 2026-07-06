---
name: "mobile-design-system"
description: "Generate and maintain a DESIGN.md file that serves as the single source of truth for all design tokens in a cross-platform mobile application."
source_type: "skill"
source_file: "skills/mobile-design-system.md"
---

# mobile-design-system

Migrated from `skills/mobile-design-system.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Mobile Design System

Generate and maintain a DESIGN.md file that serves as the single source of truth for all design tokens in a cross-platform mobile application.

## Problem

Mobile teams frequently suffer from design drift: colors defined in Figma diverge from code, iOS and Android ship different shades, dark mode is bolted on as an afterthought, and accessibility compliance is never validated. Without a canonical token file, every component author invents their own magic numbers.

## Solution

### 1. Token Extraction from Figma

When a Figma export (JSON or CSS variables) is available, parse it into a normalized token structure:

```typescript
// scripts/extract-figma-tokens.ts
interface FigmaTokenSet {
  colors: Record<string, { value: string; description?: string }>;
  typography: Record<string, {
    fontFamily: string;
    fontSize: number;
    fontWeight: string;
    lineHeight: number;
    letterSpacing: number;
  }>;
  spacing: Record<string, number>;
  radii: Record<string, number>;
  shadows: Record<string, {
    color: string;
    offsetX: number;
    offsetY: number;
    blur: number;
    spread?: number;
  }>;
}

function extractTokens(figmaJson: any): FigmaTokenSet {
  // Walk Figma variables/styles export
  const colors: FigmaTokenSet['colors'] = {};
  for (const [name, variable] of Object.entries(figmaJson.variables ?? {})) {
    if ((variable as any).type === 'COLOR') {
      colors[toKebabCase(name)] = {
        value: rgbaToHex((variable as any).value),
        description: (variable as any).description,
      };
    }
  }
  // ... extract typography, spacing, radii, shadows
  return { colors, typography: {}, spacing: {}, radii: {}, shadows: {} };
}
```

### 2. Token Extraction from Existing Code

When no Figma export exists, scan the codebase for hardcoded values:

```bash
# Find all hex colors in TypeScript/Dart files
grep -rn '#[0-9A-Fa-f]\{3,8\}' --include='*.ts' --include='*.tsx' --include='*.dart' src/
# Find all fontSize/fontWeight declarations
grep -rn 'fontSize\|fontWeight\|letterSpacing' --include='*.ts' --include='*.tsx' src/
```

### 3. Semantic Color Naming

Map raw colors to semantic roles used across both platforms:

```typescript
// design-tokens/colors.ts
export const semanticColors = {
  // Surface hierarchy
  background:       { light: '#FFFFFF', dark: '#000000' },
  surface:          { light: '#F2F2F7', dark: '#1C1C1E' },
  surfaceElevated:  { light: '#FFFFFF', dark: '#2C2C2E' },

  // Content hierarchy
  textPrimary:      { light: '#000000', dark: '#FFFFFF' },
  textSecondary:    { light: '#3C3C43', dark: '#EBEBF5' },
  textTertiary:     { light: '#8E8E93', dark: '#636366' },

  // Accent / brand
  primary:          { light: '#007AFF', dark: '#0A84FF' },
  primaryContainer: { light: '#D6EAFF', dark: '#003A70' },

  // Feedback
  error:            { light: '#FF3B30', dark: '#FF453A' },
  success:          { light: '#34C759', dark: '#30D158' },
  warning:          { light: '#FF9500', dark: '#FF9F0A' },

  // Borders & dividers
  border:           { light: '#C6C6C8', dark: '#38383A' },
  divider:          { light: '#E5E5EA', dark: '#2C2C2E' },
} as const;
```

### 4. Platform-Adaptive Typography Tokens

```typescript
// design-tokens/typography.ts
import { Platform } from 'react-native';

const iosFontFamily = 'System'; // resolves to SF Pro
const androidFontFamily = 'Roboto';

export const typography = {
  displayLarge:  { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 34, fontWeight: '700' as const, lineHeight: 41, letterSpacing: 0.37 },
  displayMedium: { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 28, fontWeight: '700' as const, lineHeight: 34, letterSpacing: 0.36 },
  titleLarge:    { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 22, fontWeight: '700' as const, lineHeight: 28, letterSpacing: 0.35 },
  titleMedium:   { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 17, fontWeight: '600' as const, lineHeight: 22, letterSpacing: -0.41 },
  bodyLarge:     { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 17, fontWeight: '400' as const, lineHeight: 22, letterSpacing: -0.41 },
  bodyMedium:    { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 15, fontWeight: '400' as const, lineHeight: 20, letterSpacing: -0.24 },
  bodySmall:     { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 13, fontWeight: '400' as const, lineHeight: 18, letterSpacing: -0.08 },
  labelLarge:    { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 15, fontWeight: '600' as const, lineHeight: 20, letterSpacing: -0.24 },
  caption:       { fontFamily: Platform.select({ ios: iosFontFamily, android: androidFontFamily })!, fontSize: 12, fontWeight: '400' as const, lineHeight: 16, letterSpacing: 0 },
};
```

### 5. Flutter Token Equivalents

```dart
// lib/design/tokens.dart
import 'package:flutter/material.dart';

class AppColors {
  // Light theme
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF2F2F7);
  static const lightPrimary = Color(0xFF007AFF);
  static const lightError = Color(0xFFFF3B30);
  static const lightTextPrimary = Color(0xFF000000);
  static const lightTextSecondary = Color(0xFF3C3C43);
  static const lightBorder = Color(0xFFC6C6C8);

  // Dark theme
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkPrimary = Color(0xFF0A84FF);
  static const darkError = Color(0xFFFF453A);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFEBEBF5);
  static const darkBorder = Color(0xFF38383A);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
```

### 6. DESIGN.md Template

Generate a DESIGN.md at the project root containing:

```markdown
# Design System

## Colors
| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| primary | #007AFF | #0A84FF | CTA buttons, links |
| background | #FFFFFF | #000000 | Screen backgrounds |
...

## Typography
| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| displayLarge | 34 | Bold | 41 | Screen titles |
...

## Spacing Scale
4 / 8 / 16 / 24 / 32 / 48

## Shadows
| Level | Offset | Blur | Color |
|-------|--------|------|-------|
| sm | 0,1 | 3 | rgba(0,0,0,0.1) |
...

## Accessibility
- All text passes WCAG AA contrast (4.5:1 normal, 3:1 large)
- Touch targets minimum 44x44pt (iOS) / 48x48dp (Android)
```

## Why This Works

A single DESIGN.md file with platform-aware tokens eliminates the most common source of UI bugs in cross-platform apps: inconsistency. When every component imports from the same token set, visual drift between iOS and Android becomes impossible. The semantic naming layer means designers and developers share vocabulary, and the built-in accessibility checks catch contrast failures before they reach QA.

## Edge Cases

- **Custom fonts**: when the app uses branded fonts, the typography tokens must include font file registration steps for both platforms
- **Dynamic type / font scaling**: iOS Dynamic Type and Android font scale must be respected; tokens should define relative sizes, not just absolute points
- **High contrast mode**: iOS and Android both offer high-contrast accessibility settings; tokens should include an optional high-contrast override set
- **Brand color conflicts**: a brand's primary color may fail contrast checks; document the accessible alternative alongside the brand color
- **Existing theme conflicts**: when integrating into a brownfield app, map existing ad-hoc values to the nearest semantic token and log discrepancies

## Verification

1. **Contrast validation**: run all foreground/background combinations through WCAG AA checker (4.5:1 for body text, 3:1 for large text)
2. **Token coverage**: grep the codebase for any remaining hardcoded hex values, font sizes, or spacing values not referencing the token set
3. **Dark mode parity**: render every screen in both light and dark mode and compare against the token table
4. **Touch target audit**: measure all interactive elements; flag anything below 44x44pt (iOS) or 48x48dp (Android)
5. **Platform rendering**: verify on a physical iOS and Android device that colors match the hex values (some Android OEMs shift colors)

## References

- Apple Human Interface Guidelines - Foundations: Color: https://developer.apple.com/design/human-interface-guidelines/color
- Material Design 3 - Color System: https://m3.material.io/styles/color
- WCAG 2.1 Contrast Requirements: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- Figma Variables API: https://www.figma.com/developers/api#variables
