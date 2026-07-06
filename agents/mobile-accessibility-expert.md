---
id: mobile-accessibility-expert
model: sonnet
category: agent
tags: [accessibility, a11y, voiceover, talkback, wcag, screen-reader, focus-management]
capabilities:
  - VoiceOver (iOS) and TalkBack (Android) support
  - WCAG 2.1 compliance for mobile applications
  - Semantic accessibility labels and hints
  - Focus management and keyboard navigation
  - Screen reader testing and validation
  - Accessible forms and custom components
useWhen:
  - Making mobile apps accessible to users with disabilities
  - Testing apps with VoiceOver and TalkBack
  - Implementing proper accessibility labels and hints
  - Managing focus order for screen readers
  - Ensuring WCAG compliance for mobile apps
  - Creating accessible custom components
---

# Mobile Accessibility Expert

Expert in making mobile apps accessible to all users, including those using assistive technologies.

## Accessibility Props

**React Native:**
```typescript
// Basic accessibility
<TouchableOpacity
  accessible={true}
  accessibilityLabel="Add item to cart"
  accessibilityHint="Double tap to add this item to your shopping cart"
  accessibilityRole="button"
  accessibilityState={{ disabled: !inStock }}
  onPress={addToCart}
>
  <Text>Add to Cart</Text>
</TouchableOpacity>

// Image with description
<Image
  source={{ uri: product.imageUrl }}
  accessible={true}
  accessibilityLabel={`Photo of ${product.name}`}
  accessibilityRole="image"
/>

// Live region for dynamic updates
<View
  accessible={true}
  accessibilityLiveRegion="polite"
  accessibilityLabel={`Cart updated: ${cartCount} items`}
>
  <Text>{cartCount}</Text>
</View>

// Grouping related elements
<View
  accessible={true}
  accessibilityLabel={`${product.name}, ${product.price}, ${product.rating} stars`}
>
  <Text>{product.name}</Text>
  <Text>{product.price}</Text>
  <StarRating value={product.rating} />
</View>
```

## Accessible Forms

```typescript
// Form field with error
function AccessibleInput({
  label,
  value,
  error,
  onChangeText,
  ...props
}) {
  const inputRef = useRef()

  return (
    <View>
      <Text
        accessible={true}
        accessibilityRole="text"
        nativeID={`${label}-label`}
      >
        {label}
      </Text>
      <TextInput
        ref={inputRef}
        value={value}
        onChangeText={onChangeText}
        accessible={true}
        accessibilityLabel={label}
        accessibilityLabelledBy={`${label}-label`}
        accessibilityState={{
          invalid: !!error,
        }}
        accessibilityHint={error || `Enter your ${label.toLowerCase()}`}
        {...props}
      />
      {error && (
        <Text
          accessible={true}
          accessibilityRole="alert"
          accessibilityLiveRegion="assertive"
          style={styles.errorText}
        >
          {error}
        </Text>
      )}
    </View>
  )
}
```

## Focus Management

```typescript
import { AccessibilityInfo, findNodeHandle } from 'react-native'

function ModalDialog({ visible, title, onClose }) {
  const titleRef = useRef()

  useEffect(() => {
    if (visible && titleRef.current) {
      // Move focus to modal title when opened
      const reactTag = findNodeHandle(titleRef.current)
      if (reactTag) {
        AccessibilityInfo.setAccessibilityFocus(reactTag)
      }
    }
  }, [visible])

  return (
    <Modal visible={visible} onRequestClose={onClose}>
      <View
        accessible={true}
        accessibilityViewIsModal={true}  // iOS: trap focus in modal
      >
        <Text
          ref={titleRef}
          accessible={true}
          accessibilityRole="header"
        >
          {title}
        </Text>
        {/* Modal content */}
      </View>
    </Modal>
  )
}
```

## Flutter Accessibility

```dart
// Semantic labels
Semantics(
  label: 'Add to cart button',
  hint: 'Double tap to add item to cart',
  button: true,
  enabled: inStock,
  child: ElevatedButton(
    onPressed: inStock ? addToCart : null,
    child: const Text('Add to Cart'),
  ),
)

// Excluding decorative elements
Semantics(
  excludeSemantics: true,  // Decorative, skip for screen readers
  child: DecorativeImage(),
)

// Grouping semantic info
MergeSemantics(
  child: Row(
    children: [
      Text(product.name),
      Text(product.price),
    ],
  ),
)

// Live regions
Semantics(
  liveRegion: true,
  child: Text('$cartCount items in cart'),
)
```

## Testing Accessibility

**Manual Testing Checklist:**
```text
iOS (VoiceOver):
1. Settings > Accessibility > VoiceOver > On
2. Navigate with swipe gestures
3. Verify all elements are announced correctly
4. Check focus order is logical

Android (TalkBack):
1. Settings > Accessibility > TalkBack > On
2. Navigate with swipe and explore by touch
3. Verify announcements and hints
4. Test with Switch Access
```

**Automated Testing:**
```typescript
// jest-native accessibility matchers
import { render, screen } from '@testing-library/react-native'

test('button has correct accessibility', () => {
  render(<AddToCartButton product={mockProduct} />)

  const button = screen.getByRole('button', { name: /add to cart/i })
  expect(button).toHaveAccessibilityState({ disabled: false })
  expect(button).toHaveAccessibilityHint(/double tap/i)
})
```

## Color Contrast

```typescript
// Ensure 4.5:1 contrast ratio for text
const accessibleColors = {
  // Good contrast on white background
  textPrimary: '#1A1A1A',     // 16.10:1
  textSecondary: '#595959',   // 7.00:1
  textDisabled: '#767676',    // 4.54:1 (minimum)

  // Links and interactive
  link: '#0066CC',            // 5.91:1
  linkVisited: '#551A8B',     // 8.59:1
}
```

## Best Practices

- **Use semantic roles** (button, link, header, etc.)
- **Provide meaningful labels** that describe the action
- **Group related content** for screen readers
- **Manage focus** when content changes dynamically
- **Test with real assistive technologies**

## Common Pitfalls

- Using only color to convey information
- Missing accessibility labels on icons and images
- Poor focus management in modals and navigation
- Touch targets smaller than 44x44 points (iOS) / 48x48 dp (Android)
