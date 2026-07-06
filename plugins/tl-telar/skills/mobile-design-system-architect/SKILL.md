---
name: "mobile-design-system-architect"
description: "Orchestrates the creation and maintenance of a comprehensive mobile design system, from token extraction through theme provider implementation and accessibility validation."
source_type: "agent"
source_file: "agents/mobile-design-system-architect.md"
---

# mobile-design-system-architect

Migrated from `agents/mobile-design-system-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Design System Architect

Orchestrates the creation and maintenance of a comprehensive mobile design system, from token extraction through theme provider implementation and accessibility validation.

## Decision Framework

### Entry Point Assessment

```text
Input Assessment
  |
  +-- Source of design truth?
  |     |
  |     +-- Figma export available
  |     |     -> Use mobile-design-system skill: Figma token extraction
  |     |
  |     +-- Existing codebase with ad-hoc styles
  |     |     -> Use mobile-design-system skill: code extraction
  |     |     -> Audit with grep for hardcoded values
  |     |
  |     +-- Starting from scratch (no design reference)
  |           -> Use prompt-to-screen skill for initial screen specs
  |           -> Generate default token set based on platform guidelines
  |
  +-- Platform target?
  |     |
  |     +-- React Native only
  |     |     -> Generate TS token files + ThemeContext
  |     |     -> Choose UI library via ui-library-integration skill
  |     |
  |     +-- Flutter only
  |     |     -> Generate Dart token files + ThemeData
  |     |     -> Configure Material 3 or Cupertino theme
  |     |
  |     +-- Both platforms (shared design system)
  |           -> Generate platform-agnostic JSON tokens
  |           -> Transform to TS and Dart via build scripts
  |
  +-- Token granularity?
        |
        +-- Small app (< 20 screens)
        |     -> Semantic tokens only (primary, surface, error, etc.)
        |     -> Single theme file
        |
        +-- Medium app (20-50 screens)
        |     -> Primitive + semantic layers
        |     -> Separate files per token category
        |
        +-- Large app / design system library
              -> Primitive + semantic + component token layers
              -> Token documentation site (Storybook)
```

### Dark Mode Strategy Decision

```text
Dark Mode Approach
  |
  +-- System-follows-device (recommended default)
  |     -> useColorScheme() / MediaQuery.platformBrightnessOf()
  |     -> Two complete token sets: light + dark
  |
  +-- User-selectable (light / dark / system)
  |     -> Persist preference in AsyncStorage / SharedPreferences
  |     -> Three-way toggle in settings
  |
  +-- No dark mode (rare, usually brand requirement)
        -> Single token set
        -> Document the decision and rationale
```

## Core Patterns

### Pattern 1: DESIGN.md Generation Pipeline

```text
Step 1: Extract raw values
  -> Scan Figma JSON or codebase for colors, fonts, spacing, shadows
  -> Deduplicate and normalize (hex -> uppercase, font weight -> numeric)

Step 2: Classify into semantic roles
  -> Map raw values to semantic names (primary, surface, textPrimary, etc.)
  -> Identify gaps (missing error color, no disabled state, etc.)

Step 3: Generate platform-specific tokens
  -> React Native: TypeScript const objects
  -> Flutter: Dart const classes
  -> Both: JSON intermediate + transform scripts

Step 4: Validate accessibility
  -> Run all foreground/background pairs through contrast checker
  -> Verify touch target sizes in component specs
  -> Flag failures with suggested alternatives

Step 5: Produce DESIGN.md
  -> Assemble all tokens into a single reference document
  -> Include color swatches (hex), type scale, spacing table
  -> Add usage guidelines and do/don't examples

Step 6: Generate theme provider code
  -> React Native: ThemeContext + useTheme hook
  -> Flutter: ThemeData factory + ThemeExtension
```

### Pattern 2: Token Consistency Enforcement

```typescript
// scripts/lint-design-tokens.ts
// Run as a pre-commit hook to catch hardcoded values

import * as fs from 'fs';
import * as path from 'path';

const TOKEN_IMPORT_PATTERN = /from ['"].*design-tokens|from ['"].*theme/;
const HARDCODED_COLOR = /#[0-9A-Fa-f]{3,8}|rgba?\(/;
const HARDCODED_FONT_SIZE = /fontSize:\s*\d+/;

function lintFile(filePath: string): string[] {
  const content = fs.readFileSync(filePath, 'utf-8');
  const violations: string[] = [];

  // Skip token definition files themselves
  if (filePath.includes('design-tokens') || filePath.includes('theme')) return [];

  const lines = content.split('\n');
  const importsTokens = TOKEN_IMPORT_PATTERN.test(content);

  lines.forEach((line, index) => {
    if (HARDCODED_COLOR.test(line) && !line.includes('// token-exempt')) {
      violations.push(`${filePath}:${index + 1} - Hardcoded color found: ${line.trim()}`);
    }
    if (HARDCODED_FONT_SIZE.test(line) && !line.includes('// token-exempt')) {
      violations.push(`${filePath}:${index + 1} - Hardcoded font size: ${line.trim()}`);
    }
  });

  return violations;
}
```

### Pattern 3: Theme Provider Architecture (React Native)

```typescript
// src/theme/ThemeProvider.tsx
import React, { createContext, useContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { lightTokens, darkTokens, AppTheme } from '../design-tokens';

const ThemeContext = createContext<AppTheme>(lightTokens);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const colorScheme = useColorScheme();
  const theme = useMemo(
    () => (colorScheme === 'dark' ? darkTokens : lightTokens),
    [colorScheme],
  );

  return (
    <ThemeContext.Provider value={theme}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme(): AppTheme {
  return useContext(ThemeContext);
}

// For styled-components or Tamagui, integrate via their theme systems instead
```

### Pattern 4: Theme Provider Architecture (Flutter)

```dart
// lib/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => AppTheme.light();
  ThemeData get darkTheme => AppTheme.dark();

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

// In MaterialApp:
// MaterialApp(
//   theme: themeProvider.lightTheme,
//   darkTheme: themeProvider.darkTheme,
//   themeMode: themeProvider.themeMode,
// )
```

### Pattern 5: Cross-Platform Token Pipeline

```json
// design-tokens/tokens.json (platform-agnostic source)
{
  "color": {
    "primary": { "light": "#007AFF", "dark": "#0A84FF" },
    "background": { "light": "#FFFFFF", "dark": "#000000" },
    "surface": { "light": "#F2F2F7", "dark": "#1C1C1E" },
    "textPrimary": { "light": "#000000", "dark": "#FFFFFF" },
    "error": { "light": "#FF3B30", "dark": "#FF453A" }
  },
  "spacing": {
    "xs": 4, "sm": 8, "md": 16, "lg": 24, "xl": 32, "xxl": 48
  },
  "typography": {
    "displayLarge": { "size": 34, "weight": 700, "lineHeight": 41 },
    "titleLarge": { "size": 22, "weight": 700, "lineHeight": 28 },
    "bodyLarge": { "size": 17, "weight": 400, "lineHeight": 22 }
  },
  "radius": {
    "sm": 4, "md": 8, "lg": 16, "full": 9999
  }
}
```

```bash
# Transform to platform-specific files
node scripts/generate-rn-tokens.js   # -> src/design-tokens/index.ts
node scripts/generate-flutter-tokens.js  # -> lib/design/tokens.dart
```

## Anti-Patterns

- **Token explosion**: creating a unique token for every single component state instead of composing from semantic tokens; leads to hundreds of unmaintainable tokens
- **Platform-specific token names**: naming tokens `iosBlue` or `androidGreen` instead of semantic names; breaks cross-platform consistency
- **Skipping the semantic layer**: using primitive tokens (`blue-500`) directly in components instead of mapping through semantic names (`primary`); makes theme changes require touching every component
- **Hardcoded dark mode offsets**: calculating dark mode colors by adjusting lightness of light-mode colors at runtime; produces inconsistent results; define explicit dark tokens instead
- **Ignoring existing library tokens**: if using React Native Paper or Material 3, fighting their token system instead of extending it; leads to two parallel theme systems
- **No contrast validation**: shipping tokens without checking contrast ratios; causes accessibility failures and potential legal issues

## Tool Commands

```bash
# Extract colors from existing codebase
grep -rn '#[0-9A-Fa-f]\{3,8\}' --include='*.ts' --include='*.tsx' --include='*.dart' src/ lib/

# Validate contrast ratios (requires contrast-ratio npm package)
npx contrast-ratio "#007AFF" "#FFFFFF"  # Should be >= 4.5:1

# Generate token files from JSON
node scripts/generate-tokens.js

# Lint for hardcoded values (custom script from Pattern 2)
npx ts-node scripts/lint-design-tokens.ts src/

# Check dark mode coverage
grep -rn 'useColorScheme\|MediaQuery.platformBrightnessOf' src/ lib/ | wc -l

# Verify theme provider is at app root
grep -n 'ThemeProvider' src/App.tsx lib/main.dart
```

## Escalation Paths

- **Brand guidelines conflict with accessibility**: escalate to design team with specific contrast ratio failures and suggested accessible alternatives
- **Third-party library theme incompatibility**: escalate to the library's issue tracker with a minimal reproduction; temporarily wrap with an adapter
- **Performance issues from runtime theme switching**: escalate to performance optimization; consider compile-time themes (Tamagui) or reduce theme context consumers
- **Cross-platform token divergence**: when iOS and Android designers insist on different values, document both in DESIGN.md with platform annotations rather than forcing unification

## Best Practices

- **Single source of truth**: maintain tokens in one location (JSON file or DESIGN.md) and generate platform code from it
- **Semantic naming always**: never expose primitive color names to component authors; only semantic names
- **Version your design system**: tag DESIGN.md changes in git; breaking token changes need a migration guide
- **Test theme changes visually**: after modifying tokens, render a screen gallery in both themes before committing
- **Document decisions**: record why a color was chosen, not just what it is; future maintainers need the rationale
- **Progressive adoption**: when migrating a brownfield app, replace hardcoded values one screen at a time; do not attempt a big-bang migration

## Referenced Skills

- `mobile-design-system` - Token extraction and DESIGN.md generation
- `ui-library-integration` - Library selection and theme integration
- `component-scaffolding` - Generating components that consume design tokens
- `theming-dark-mode` - Dark mode implementation patterns
- `accessibility-patterns` - Accessibility validation and compliance
