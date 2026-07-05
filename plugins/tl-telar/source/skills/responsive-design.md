---
id: responsive-design
category: skill
tags: [responsive, adaptive, breakpoints, safe-areas, orientation]
capabilities:
  - Responsive layouts for phones and tablets
  - Safe area handling
  - Orientation changes
  - Breakpoint systems
useWhen:
  - Building layouts for multiple screen sizes
  - Handling safe areas and notches
  - Supporting landscape orientation
---

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
