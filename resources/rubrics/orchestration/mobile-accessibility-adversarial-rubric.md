# Mobile Accessibility Adversarial Rubric

## Purpose

Used by the conditional Adversarial Mobile UX/A11y Reviewer (fired only when WU `fileScope` intersects UI directories — see `skills/orchestration/mobile-adversarial-review.md`).

## Reviewer mode

**Adversarial.** Same discipline. Fresh `Task()` instance.

## Evaluation criteria

### Y. Accessibility failures (Y for "ya11y" — distinguishes from A=Feasibility in sub-spec 1's plan rubric)

A WU FAILS accessibility review if any of:

- Y1. Touchable element (button, Pressable, TouchableOpacity, GestureDetector) is smaller than the platform minimum (44pt iOS / 48dp Android) AND has no `hitSlop` compensation.
- Y2. Image or icon without an accessible label (`accessibilityLabel` in RN / `semanticsLabel` in Flutter / `contentDescription` in Android views) AND not marked decorative (`accessibilityElementsHidden` or equivalent).
- Y3. Custom interactive component (not built-in) without `accessibilityRole` set.
- Y4. Text color and background fail WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large). Reviewer cannot programmatically compute contrast but flags hardcoded color pairs that look suspect (e.g., light gray text on white background).
- Y5. New screen adds form fields without keyboard-type, return-key-type, or autocomplete hints when appropriate (`textContentType="emailAddress"` etc.).
- Y6. Dynamic font scaling is broken: text uses `fontSize: 14` without `allowFontScaling` set OR explicit responsive sizing. Flutter analog: `MediaQuery.textScaler` not consulted.
- Y7. RTL layout is broken: hardcoded `marginLeft`/`paddingLeft` (instead of `marginStart`/`paddingStart`) on new layout code, OR mirrored icons (chevrons, arrows) without conditional flip.
- Y8. New screen adds top-level scrollable without `keyboardShouldPersistTaps` (RN) or appropriate `resizeToAvoidBottomInset` (Flutter), causing tap-through bugs near the keyboard.
- Y9. Animated reveal of important content without `reduceMotion` accommodation.

## Verdict format

JSON per the schema. Rule IDs Y1-Y9. Reviewer field: `"mobile-accessibility"`.
