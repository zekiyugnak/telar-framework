---
name: "design-system"
description: "Create a complete mobile design system with tokens, DESIGN.md, theme providers, and accessibility validation"
source_type: "command"
source_file: "commands/design-system.md"
---

# design-system

Migrated from `commands/design-system.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:design-system`; invoke it as `$design-system` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Design System

Create a complete mobile design system from analysis through implementation, producing design tokens, DESIGN.md, theme providers, and accessibility validation.

## Phase 1: Analyze (0-20%)

### Load Agents and Skills
```yaml
agents:
  - mobile-design-system-architect
skills:
  - mobile-design-system
```

### Determine Source
Ask user to identify the source of design truth:

1. **Figma export** - user provides a Figma variables JSON export or CSS variables file
2. **Existing codebase** - extract tokens from hardcoded values in the current project
3. **From scratch** - generate a default token set based on platform guidelines and user preferences

### Figma Analysis Path
If Figma export is available:
- Parse the JSON/CSS variables file
- Catalog all color, typography, spacing, shadow, and radius values
- Map Figma layer names to semantic token names
- Identify light/dark mode variable sets if present

### Codebase Analysis Path
If extracting from existing code:
```bash
# Scan for colors
grep -rn '#[0-9A-Fa-f]\{3,8\}' --include='*.ts' --include='*.tsx' --include='*.dart' src/ lib/

# Scan for font sizes
grep -rn 'fontSize' --include='*.ts' --include='*.tsx' --include='*.dart' src/ lib/

# Scan for spacing values
grep -rn 'padding\|margin\|gap' --include='*.ts' --include='*.tsx' --include='*.dart' src/ lib/

# Scan for shadow definitions
grep -rn 'shadow\|elevation' --include='*.ts' --include='*.tsx' --include='*.dart' src/ lib/
```

- Deduplicate discovered values
- Group by category (color, typography, spacing, shadows)
- Identify the most frequently used values as candidates for tokens

### From Scratch Path
If starting fresh:
- Ask user for brand primary color
- Ask user for platform target (iOS-first, Android-first, or balanced)
- Generate token set based on:
  - iOS HIG color recommendations for iOS-first
  - Material 3 color system for Android-first
  - Blended defaults for balanced approach

### Output
- Inventory of raw design values with frequency counts
- Proposed semantic token mapping
- List of gaps or conflicts to resolve

## Phase 2: Generate Tokens (20-40%)

### Load Skills
```yaml
skills:
  - mobile-design-system
  - ui-library-integration
```

### Create Token Files

#### React Native Project
Generate `src/design-tokens/` directory with:

```
src/design-tokens/
  colors.ts          # Semantic color tokens with light/dark
  typography.ts      # Type scale with platform fonts
  spacing.ts         # Spacing scale (4/8/16/24/32/48)
  shadows.ts         # Shadow/elevation presets
  radii.ts           # Border radius scale
  index.ts           # Barrel export of all tokens
```

#### Flutter Project
Generate `lib/design/` directory with:

```
lib/design/
  colors.dart        # AppColors class with light/dark constants
  typography.dart    # AppTypography text styles
  spacing.dart       # AppSpacing constants
  shadows.dart       # AppShadows box shadow presets
  radii.dart         # AppRadii border radius constants
  tokens.dart        # Barrel export
```

### Token Naming Convention
Apply consistent naming:
- Colors: `primary`, `primaryContainer`, `surface`, `surfaceVariant`, `background`, `error`, `textPrimary`, `textSecondary`, `textTertiary`, `border`, `divider`
- Typography: `displayLarge`, `displayMedium`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `bodySmall`, `labelLarge`, `caption`
- Spacing: `xs` (4), `sm` (8), `md` (16), `lg` (24), `xl` (32), `xxl` (48)
- Radii: `sm` (4), `md` (8), `lg` (16), `full` (9999)
- Shadows: `sm`, `md`, `lg`

### Output
- All token files generated with typed exports
- Both light and dark mode values defined
- Platform-specific values where needed (fonts, elevation vs shadow)

## Phase 3: Create DESIGN.md (40-60%)

### Load Skills
```yaml
skills:
  - mobile-design-system
```

### Generate DESIGN.md at Project Root

Structure the document with these sections:

1. **Overview** - design system purpose and scope
2. **Colors** - table of all semantic colors with hex values for light and dark
3. **Typography** - type scale table with size, weight, line height, and usage
4. **Spacing** - spacing scale with visual reference
5. **Shadows** - shadow presets with offset, blur, and color
6. **Border Radii** - radius scale with usage guidelines
7. **Accessibility** - contrast ratio compliance status, touch target requirements
8. **Platform Notes** - iOS-specific and Android-specific considerations
9. **Usage Guidelines** - do/don't examples for token usage
10. **Token File Locations** - file paths for developer reference

### Populate Tables

Color table example:
```markdown
| Token | Light | Dark | Contrast (on bg) | Usage |
|-------|-------|------|-------------------|-------|
| primary | #007AFF | #0A84FF | 4.6:1 / 4.3:1 | CTA buttons, links, active states |
| error | #FF3B30 | #FF453A | 4.5:1 / 4.2:1 | Error messages, destructive actions |
```

### Output
- DESIGN.md file at project root
- All token values documented in human-readable tables
- Contrast ratios calculated and recorded
- Usage guidelines with examples

## Phase 4: Theme Providers (60-80%)

### Load Agents and Skills
```yaml
agents:
  - mobile-design-system-architect
skills:
  - ui-library-integration
  - theming-dark-mode
```

### React Native Theme Provider

Generate `src/theme/` directory:

```
src/theme/
  ThemeProvider.tsx   # Context provider with useColorScheme
  useTheme.ts        # Hook to access current theme
  types.ts           # TypeScript type for the theme object
  index.ts           # Barrel export
```

Key implementation points:
- Use `useColorScheme()` for system theme detection
- Memoize theme object to prevent unnecessary re-renders
- Export a typed `useTheme()` hook
- If a UI library is in use (Tamagui, RN Paper, gluestack), integrate tokens into the library's theme system instead of a custom context

### Flutter Theme Provider

Generate theme configuration:

```
lib/theme/
  app_theme.dart       # ThemeData.light() and ThemeData.dark() factories
  theme_provider.dart  # ChangeNotifier for user theme preference
  theme_extensions.dart # Custom ThemeExtension for non-Material tokens
```

Key implementation points:
- Use `ThemeData` with `useMaterial3: true`
- Map all design tokens to `ColorScheme` properties
- Use `ThemeExtension` for tokens that do not map to Material properties (custom spacing, shadows)
- Support `ThemeMode.system`, `ThemeMode.light`, and `ThemeMode.dark`

### Wire Into App Entry Point

React Native:
```typescript
// App.tsx
import { ThemeProvider } from './src/theme';

export default function App() {
  return (
    <ThemeProvider>
      <NavigationContainer>
        {/* ... */}
      </NavigationContainer>
    </ThemeProvider>
  );
}
```

Flutter:
```dart
// lib/main.dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.system,
  // ...
)
```

### Output
- Theme provider files generated
- App entry point updated with theme provider wrapping
- Dark mode switching functional
- Typed theme access available throughout the app

## Phase 5: Validate Accessibility (80-100%)

### Load Skills
```yaml
skills:
  - mobile-design-system
  - accessibility-patterns
```

### Contrast Ratio Validation

Check every foreground/background token combination:

```
Minimum ratios (WCAG AA):
  - Normal text (< 18pt): 4.5:1
  - Large text (>= 18pt or >= 14pt bold): 3:1
  - UI components and graphical objects: 3:1
```

For each pair:
- Calculate contrast ratio using relative luminance formula
- Flag any pair that fails AA requirements
- Suggest adjusted color values that maintain brand identity while meeting contrast

### Touch Target Validation

Verify design tokens support minimum touch target sizes:
- iOS: 44x44 points minimum (Apple HIG)
- Android: 48x48 dp minimum (Material Design)

Check that button height tokens, list row heights, and interactive component sizes meet these minimums.

### Generate Accessibility Report

Append to DESIGN.md or create a separate `ACCESSIBILITY.md`:

```markdown
## Accessibility Audit

### Contrast Ratios
| Foreground | Background | Ratio | Status | Mode |
|-----------|-----------|-------|--------|------|
| textPrimary | background | 21:1 | PASS | Light |
| textPrimary | background | 21:1 | PASS | Dark |
| textSecondary | background | 7.2:1 | PASS | Light |
| primary | background | 4.6:1 | PASS | Light |

### Touch Targets
| Component | Min Height | Status |
|-----------|-----------|--------|
| Button (md) | 44pt / 48dp | PASS |
| ListRow | 44pt / 48dp | PASS |
| IconButton | 44pt / 48dp | PASS |

### Recommendations
- [Any failing items with suggested fixes]
```

### Output
- All contrast ratios validated and documented
- Touch target sizes confirmed compliant
- Accessibility report generated
- Any failures flagged with remediation suggestions

## Completion Checklist

- [ ] Design source analyzed (Figma, code, or from scratch)
- [ ] Token files generated for target platform(s)
- [ ] DESIGN.md created at project root with all token tables
- [ ] Theme provider implemented and wired into app entry point
- [ ] Dark mode switching functional
- [ ] Contrast ratios validated for all token pairs
- [ ] Touch target sizes confirmed compliant
- [ ] No hardcoded colors, font sizes, or spacing in component code
- [ ] Accessibility report generated
