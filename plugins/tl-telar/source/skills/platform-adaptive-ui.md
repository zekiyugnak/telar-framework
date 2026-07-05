---
id: platform-adaptive-ui
category: skill
tags: [ios-hig, material-design, adaptive, platform-specific]
capabilities:
  - iOS Human Interface Guidelines patterns
  - Material Design components
  - Platform-adaptive components
  - Native feel on each platform
useWhen:
  - Creating platform-specific UI
  - Following iOS/Android conventions
  - Building adaptive components
---

# Platform-Adaptive UI

Creating UIs that feel native on iOS and Android.

## React Native

```typescript
import { Platform } from 'react-native'

const AdaptiveButton = ({ title, onPress }) => {
  if (Platform.OS === 'ios') {
    return (
      <TouchableOpacity style={styles.iosButton} onPress={onPress}>
        <Text style={styles.iosText}>{title}</Text>
      </TouchableOpacity>
    )
  }

  return (
    <Pressable
      style={styles.androidButton}
      onPress={onPress}
      android_ripple={{ color: 'rgba(0,0,0,0.1)' }}
    >
      <Text style={styles.androidText}>{title.toUpperCase()}</Text>
    </Pressable>
  )
}

// Platform-specific files
// Button.ios.tsx
// Button.android.tsx
import Button from './Button' // Auto-selects correct file
```

## Flutter

```dart
import 'dart:io' show Platform;

class AdaptiveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(onPressed: onPressed, child: Text(label));
    }
    return ElevatedButton(onPressed: onPressed, child: Text(label));
  }
}

// Using adaptive icons
Icon(Platform.isIOS ? CupertinoIcons.back : Icons.arrow_back)
```

## Platform Conventions

| Aspect | iOS | Android |
|--------|-----|---------|
| Back | Swipe edge, "< Back" | Hardware/nav button |
| Buttons | Rounded, sentence case | Contained, uppercase |
| Modals | Slide up | Fade in |
| Lists | Chevron indicator | Touch ripple |
| Typography | SF Pro | Roboto |

## Best Practices

- Follow platform conventions
- Use platform-specific icons
- Match navigation patterns
- Test on both platforms
