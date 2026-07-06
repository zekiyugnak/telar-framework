---
name: "responsive-design"
description: "Building responsive layouts for phones and tablets."
source_type: "skill"
source_file: "skills/responsive-design.md"
---

# responsive-design

Migrated from `skills/responsive-design.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Responsive Mobile Design

Building responsive layouts for phones and tablets.

## React Native

```typescript
import { useWindowDimensions } from 'react-native'
import { useSafeAreaInsets } from 'react-native-safe-area-context'

function useResponsive() {
  const { width, height } = useWindowDimensions()
  const insets = useSafeAreaInsets()

  return {
    isPhone: width < 768,
    isTablet: width >= 768,
    isLandscape: width > height,
    columns: width >= 768 ? 3 : width >= 480 ? 2 : 1,
    safeArea: insets,
  }
}

// Safe area wrapper
<View style={{
  paddingTop: insets.top,
  paddingBottom: insets.bottom,
  paddingLeft: insets.left,
  paddingRight: insets.right,
}}>
  <Content />
</View>
```

## Flutter

```dart
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints, bool) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 768;
        return builder(context, constraints, isTablet);
      },
    );
  }
}

// Safe area
SafeArea(
  child: Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width > 768 ? 32 : 16,
    ),
    child: content,
  ),
)
```

## Breakpoint System

```yaml
Phone: < 480px (1 column)
Large Phone: 480-767px (2 columns)
Tablet: 768-1023px (3 columns)
Large Tablet: >= 1024px (4 columns)
```

## Best Practices

- Use percentage-based widths for flexibility
- Always handle safe areas
- Test on multiple device sizes
- Support both orientations when sensible
