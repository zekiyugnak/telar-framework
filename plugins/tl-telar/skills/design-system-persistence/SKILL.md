---
name: "design-system-persistence"
description: "Hierarchical design persistence with a global MASTER.md for tokens and per-screen override files, mapped to Apple HIG and Material Design 3 conventions."
source_type: "skill"
source_file: "skills/design-system-persistence.md"
---

# design-system-persistence

Migrated from `skills/design-system-persistence.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Design System Persistence

Hierarchical design persistence with a global MASTER.md for tokens and per-screen override files, mapped to Apple HIG and Material Design 3 conventions.

## Problem

Design decisions made in one session are forgotten in the next. Colors, spacing, and typography drift across screens. Without a persistent design system, each new screen introduces slight inconsistencies. Developers waste time reverse-engineering design intent from existing code.

## Solution

### 1. MASTER.md — Global Design Tokens

Create `designs/MASTER.md` in the project root:

```markdown
# Design System — [App Name]

## Colors

### Light Theme
| Token | Value | HIG | MD3 | Usage |
|-------|-------|-----|-----|-------|
| primary | #2563EB | systemBlue | md.sys.color.primary | Buttons, links, active states |
| primary-container | #DBEAFE | — | md.sys.color.primary-container | Selected backgrounds |
| secondary | #7C3AED | systemPurple | md.sys.color.secondary | Accents, badges |
| background | #FFFFFF | systemBackground | md.sys.color.background | Screen backgrounds |
| surface | #F8FAFC | secondarySystemBackground | md.sys.color.surface | Cards, sheets |
| on-primary | #FFFFFF | — | md.sys.color.on-primary | Text on primary |
| on-surface | #0F172A | label | md.sys.color.on-surface | Primary text |
| on-surface-variant | #64748B | secondaryLabel | md.sys.color.on-surface-variant | Secondary text |
| error | #DC2626 | systemRed | md.sys.color.error | Error states |
| outline | #CBD5E1 | separator | md.sys.color.outline | Borders, dividers |

### Dark Theme
| Token | Value | HIG | MD3 |
|-------|-------|-----|-----|
| primary | #60A5FA | systemBlue | md.sys.color.primary |
| background | #0F172A | systemBackground | md.sys.color.background |
| surface | #1E293B | secondarySystemBackground | md.sys.color.surface |
| on-surface | #F1F5F9 | label | md.sys.color.on-surface |
| outline | #334155 | separator | md.sys.color.outline |

## Typography

| Token | iOS (SF Pro) | Android (Roboto) | Size | Weight | Line Height |
|-------|-------------|-------------------|------|--------|-------------|
| display-large | .largeTitle | displayLarge | 34 | Bold | 41 |
| headline | .title1 | headlineMedium | 28 | Bold | 34 |
| title | .title2 | titleLarge | 22 | Semibold | 28 |
| title-small | .title3 | titleMedium | 17 | Semibold | 22 |
| body | .body | bodyLarge | 17 | Regular | 22 |
| body-small | .callout | bodyMedium | 15 | Regular | 20 |
| caption | .caption1 | bodySmall | 12 | Regular | 16 |
| label | .footnote | labelLarge | 13 | Medium | 18 |

## Spacing

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4 | Tight element gaps |
| sm | 8 | Related element spacing |
| md | 16 | Section padding, card padding |
| lg | 24 | Section spacing |
| xl | 32 | Screen-level spacing |
| 2xl | 48 | Major section breaks |

## Radius

| Token | Value | Usage |
|-------|-------|-------|
| sm | 8 | Buttons, inputs |
| md | 12 | Cards, sheets |
| lg | 16 | Modals, large cards |
| full | 9999 | Pills, avatars |

## Shadows

| Token | iOS | Android (Elevation) | Usage |
|-------|-----|---------------------|-------|
| sm | shadow(radius: 2, opacity: 0.1) | elevation: 1 | Subtle lift |
| md | shadow(radius: 4, opacity: 0.15) | elevation: 3 | Cards |
| lg | shadow(radius: 8, opacity: 0.2) | elevation: 6 | Sheets, modals |

## Animation

| Token | Duration | Curve | Usage |
|-------|----------|-------|-------|
| fast | 150ms | easeOut | Micro-interactions |
| normal | 250ms | easeInOut | State transitions |
| slow | 350ms | easeInOut | Screen transitions |
```

### 2. Per-Screen Overrides

Create `designs/[ScreenName].md` for screens that deviate from MASTER.md:

```markdown
# Design: HomeScreen

**Overrides MASTER.md for:**
- Background uses gradient instead of flat color
- Hero section uses display-large typography
- Card shadows use lg instead of md

## Overrides
| Token | MASTER.md Value | Override | Reason |
|-------|----------------|----------|--------|
| background | #FFFFFF | linear-gradient(#EFF6FF, #FFFFFF) | Visual hierarchy for hero |
| card-shadow | md | lg | Elevated cards for featured content |

## Layout
- Hero section: 40% screen height
- Content grid: 2 columns on tablet, 1 on phone
- Bottom tab bar visible
```

### 3. Override Resolution

When generating code for a screen:

1. Load `designs/MASTER.md` for global tokens
2. Check if `designs/[ScreenName].md` exists
3. If override exists: merge screen tokens over global tokens (screen wins)
4. If no override: use global tokens only

### 4. Code Translation

#### React Native
```typescript
// src/theme/tokens.ts (generated from MASTER.md)
export const colors = {
  light: {
    primary: '#2563EB',
    primaryContainer: '#DBEAFE',
    background: '#FFFFFF',
    surface: '#F8FAFC',
    onSurface: '#0F172A',
    // ...
  },
  dark: {
    primary: '#60A5FA',
    background: '#0F172A',
    surface: '#1E293B',
    onSurface: '#F1F5F9',
    // ...
  },
} as const;

export const spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32, '2xl': 48 } as const;
export const radius = { sm: 8, md: 12, lg: 16, full: 9999 } as const;
```

#### Flutter
```dart
// lib/theme/tokens.dart (generated from MASTER.md)
abstract class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryContainer = Color(0xFFDBEAFE);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8FAFC);
  static const onSurface = Color(0xFF0F172A);
}

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
```

## Verification

1. `designs/MASTER.md` exists with all token categories (colors, typography, spacing, radius)
2. Both light and dark theme colors are defined
3. Token names map to Apple HIG and Material Design 3 equivalents
4. Per-screen override files only contain actual deviations (not duplicates of MASTER.md)
5. Code theme files match MASTER.md token values

## References

- Apple HIG Colors: https://developer.apple.com/design/human-interface-guidelines/color
- Material Design 3 Color: https://m3.material.io/styles/color/overview
- Material Design 3 Typography: https://m3.material.io/styles/typography/overview
