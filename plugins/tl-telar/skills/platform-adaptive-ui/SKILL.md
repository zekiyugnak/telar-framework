---
name: "platform-adaptive-ui"
description: "Creating UIs that feel native on iOS and Android."
source_type: "skill"
source_file: "skills/platform-adaptive-ui.md"
---

# platform-adaptive-ui

Migrated from `skills/platform-adaptive-ui.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
