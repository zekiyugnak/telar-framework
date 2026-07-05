# Platform Conventions Rule

Always follow platform-specific conventions for iOS (Apple HIG) and Android (Material Design 3). Detect the target platform and apply the appropriate guidelines.

## Platform Detection

Check `Platform.OS` usage in React Native or target platform in Flutter to determine which conventions apply. When building cross-platform, apply both.

## DO

### Touch Targets
- **iOS**: Minimum 44x44 points ([HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons))
- **Android**: Minimum 48x48 dp ([MD3: Touch targets](https://m3.material.io/foundations/accessible-design/accessibility-basics#28032e45-c598-450c-b355-f9fe737b1571))
- Add adequate spacing between interactive elements (8dp minimum)

### Navigation
- **iOS**: Use `UINavigationController` patterns — push/pop, swipe-back gesture, large titles ([HIG: Navigation](https://developer.apple.com/design/human-interface-guidelines/navigation))
- **Android**: Use Material back behavior, top app bar, navigation drawer or bottom navigation ([MD3: Navigation](https://m3.material.io/components/navigation-bar/overview))
- Tab bar at bottom on both platforms (iOS standard, Material Bottom Navigation)
- Maximum 5 top-level tabs

### Buttons & Actions
- **iOS**: Primary actions right-aligned, use system button styles, trailing swipe for delete ([HIG: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons))
- **Android**: Use FAB for primary creation action, use filled/outlined/text button hierarchy ([MD3: Buttons](https://m3.material.io/components/buttons/overview))

### Typography
- **iOS**: Use Dynamic Type / SF Pro system font, support text scaling ([HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography))
- **Android**: Use Material type scale / Roboto, support font scaling ([MD3: Typography](https://m3.material.io/styles/typography/overview))

### Safe Areas
- **iOS**: Respect safe area insets (notch, home indicator, Dynamic Island)
- **Android**: Handle status bar, navigation bar, display cutouts
- Use `SafeAreaView` (RN) or `SafeArea` (Flutter) for all screens

### Alerts & Dialogs
- **iOS**: Use `Alert` with "Cancel" on left, destructive actions in red ([HIG: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts))
- **Android**: Use Material Dialog, positive action on right ([MD3: Dialogs](https://m3.material.io/components/dialogs/overview))

### Lists
- **iOS**: Use inset grouped style for settings, plain for data lists
- **Android**: Use Material list tiles with proper leading/trailing widgets
- Both: Support swipe actions where appropriate

## DON'T

- Don't use Android-style back arrow on iOS (use system back gesture)
- Don't use iOS-style segmented controls on Android (use tabs)
- Don't put a hamburger menu on iOS (use tab bar)
- Don't use Material FAB on iOS without adapting to platform feel
- Don't ignore Dynamic Island / notch safe areas
- Don't hardcode font sizes — always support text scaling
- Don't use custom gestures that conflict with system gestures (swipe from edge = back)

## Platform-Adaptive Patterns

```typescript
// React Native — platform-specific styles
import { Platform, StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  button: {
    minHeight: Platform.select({ ios: 44, android: 48 }),
    borderRadius: Platform.select({ ios: 10, android: 20 }),
  },
  header: {
    ...Platform.select({
      ios: { shadowColor: '#000', shadowOpacity: 0.1, shadowRadius: 4 },
      android: { elevation: 4 },
    }),
  },
});
```

```dart
// Flutter — platform-adaptive widgets
Widget build(BuildContext context) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

  return isIOS
      ? CupertinoAlertDialog(
          title: Text('Delete Item?'),
          actions: [
            CupertinoDialogAction(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
            CupertinoDialogAction(isDestructiveAction: true, child: Text('Delete'), onPressed: onDelete),
          ],
        )
      : AlertDialog(
          title: Text('Delete Item?'),
          actions: [
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
            FilledButton(child: Text('Delete'), onPressed: onDelete),
          ],
        );
}
```

This rule is enforced during code review (`commands/review-code.md`) and referenced by `skills/review-gates.md`.
