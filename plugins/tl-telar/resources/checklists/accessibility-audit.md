# Mobile Accessibility Audit Checklist

WCAG AA compliance checklist adapted for mobile applications.

## Touch & Interaction

### Touch Targets
- [ ] All interactive elements minimum 44x44pt (iOS) / 48x48dp (Android)
- [ ] Adequate spacing between touch targets (minimum 8pt gap)
- [ ] No gestures that require fine motor control as only input method
- [ ] Custom gestures have alternative input methods

### Gestures
- [ ] Swipe actions have button alternatives
- [ ] Long press actions have visible alternatives
- [ ] Pinch/zoom has button controls (+/- buttons)
- [ ] Drag-and-drop has accessible alternative
- [ ] No time-dependent gestures (double-tap timing not too fast)

## Visual

### Color & Contrast
- [ ] Text contrast ratio >= 4.5:1 (normal text)
- [ ] Large text contrast ratio >= 3:1 (18pt+ or 14pt+ bold)
- [ ] Non-text elements contrast >= 3:1 (icons, borders, form fields)
- [ ] Information not conveyed by color alone
- [ ] Error states use icon + text, not just red color
- [ ] Focus indicators visible with sufficient contrast

### Typography
- [ ] Supports Dynamic Type (iOS) / font scaling (Android)
- [ ] Text scales up to 200% without clipping or overlap
- [ ] No text in images (except logos)
- [ ] Line height >= 1.5x font size for body text
- [ ] Paragraph spacing >= 2x font size

### Layout
- [ ] Content reflows on text size increase (no horizontal scrolling)
- [ ] Safe area insets respected (notch, home indicator)
- [ ] Landscape orientation supported where meaningful
- [ ] Content visible in both light and dark mode

## Screen Reader

### Labels
- [ ] All interactive elements have accessibility labels
- [ ] Labels are descriptive (not "button 1" or "tap here")
- [ ] Images have alt text (or marked as decorative)
- [ ] Form inputs have associated labels
- [ ] Error messages associated with their form fields

### Navigation
- [ ] Logical reading order matches visual layout
- [ ] Screen reader can navigate all interactive elements
- [ ] Modal dialogs trap focus correctly
- [ ] Focus moves to new content when it appears
- [ ] Back navigation announced correctly

### Announcements
- [ ] Loading states announced to screen readers
- [ ] Error messages announced immediately
- [ ] Success confirmations announced
- [ ] Dynamic content changes announced (live regions)
- [ ] Page/screen transitions announced

### React Native
```typescript
// Correct accessible component
<Pressable
  accessible={true}
  accessibilityLabel="Delete item"
  accessibilityHint="Removes this item from your cart"
  accessibilityRole="button"
  accessibilityState={{ disabled: isLoading }}
>
  <TrashIcon />
</Pressable>
```

### Flutter
```dart
// Correct accessible component
Semantics(
  label: 'Delete item',
  hint: 'Removes this item from your cart',
  button: true,
  enabled: !isLoading,
  child: IconButton(
    icon: const Icon(Icons.delete),
    onPressed: isLoading ? null : onDelete,
  ),
)
```

## Motion & Animation

- [ ] Reduced motion preference respected (`prefers-reduced-motion`)
- [ ] No auto-playing animations that can't be paused
- [ ] No flashing content (< 3 flashes per second)
- [ ] Parallax effects can be disabled
- [ ] Loading spinners don't cause seizure risk

### React Native
```typescript
import { AccessibilityInfo } from 'react-native'

const [reduceMotion, setReduceMotion] = useState(false)
useEffect(() => {
  AccessibilityInfo.isReduceMotionEnabled().then(setReduceMotion)
}, [])
```

### Flutter
```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;
```

## Forms

- [ ] Form fields have visible labels (not just placeholders)
- [ ] Required fields indicated (not just by asterisk color)
- [ ] Error messages specific and actionable
- [ ] Input types match expected data (email, phone, number keyboards)
- [ ] Autocomplete/autofill attributes set correctly
- [ ] Form can be submitted via keyboard (Return key)

## Testing

### Manual Testing
- [ ] Navigate entire app with VoiceOver (iOS)
- [ ] Navigate entire app with TalkBack (Android)
- [ ] Complete all user flows with screen reader
- [ ] Test with 200% text size
- [ ] Test with bold text enabled
- [ ] Test with reduced motion enabled
- [ ] Test with inverted colors

### Automated Testing
```bash
# iOS Accessibility Inspector
# Xcode → Open Developer Tool → Accessibility Inspector

# Android accessibility scanner
# Play Store → Accessibility Scanner app

# React Native
npx react-native-accessibility-engine

# Flutter
flutter test --tags=accessibility
```

### Tools
- [ ] Xcode Accessibility Inspector (zero issues)
- [ ] Android Accessibility Scanner (zero issues)
- [ ] Colour Contrast Analyser for mobile screenshots
- [ ] Manual screen reader walkthrough documented
