---
name: "accessibility-patterns"
description: "Making mobile apps accessible to all users."
source_type: "skill"
source_file: "skills/accessibility-patterns.md"
---

# accessibility-patterns

Migrated from `skills/accessibility-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Accessibility Patterns

Making mobile apps accessible to all users.

## React Native

```typescript
// Accessible button
<TouchableOpacity
  accessible={true}
  accessibilityLabel="Add item to cart"
  accessibilityHint="Double tap to add this item"
  accessibilityRole="button"
  accessibilityState={{ disabled: !inStock }}
  onPress={addToCart}
>
  <Text>Add to Cart</Text>
</TouchableOpacity>

// Accessible image
<Image
  source={{ uri: product.image }}
  accessible={true}
  accessibilityLabel={`Photo of ${product.name}`}
  accessibilityRole="image"
/>

// Grouping elements
<View
  accessible={true}
  accessibilityLabel={`${product.name}, ${product.price}`}
>
  <Text>{product.name}</Text>
  <Text>{product.price}</Text>
</View>

// Live regions
<View accessibilityLiveRegion="polite">
  <Text>{notification}</Text>
</View>
```

## Flutter

```dart
Semantics(
  label: 'Add to cart button',
  hint: 'Double tap to add item',
  button: true,
  enabled: inStock,
  child: ElevatedButton(
    onPressed: inStock ? addToCart : null,
    child: const Text('Add to Cart'),
  ),
)

// Exclude decorative elements
Semantics(
  excludeSemantics: true,
  child: DecorativeImage(),
)

// Merge semantics
MergeSemantics(
  child: Row(children: [Text(name), Text(price)]),
)
```

## Testing

```bash
# iOS: Settings > Accessibility > VoiceOver
# Android: Settings > Accessibility > TalkBack

# Automated testing
expect(element).toHaveAccessibilityLabel('Add to cart')
```

## WCAG Guidelines

- **Minimum touch target**: 44x44pt (iOS), 48x48dp (Android)
- **Color contrast**: 4.5:1 for normal text
- **Focus indicators**: Visible focus states
- **Motion**: Respect reduce motion preference

## Best Practices

- Test with screen readers regularly
- Provide meaningful labels for all interactive elements
- Ensure proper focus order
- Support dynamic text sizes
