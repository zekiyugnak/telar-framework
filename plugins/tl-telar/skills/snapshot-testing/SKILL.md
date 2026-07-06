---
name: "snapshot-testing"
description: "Component snapshot and visual regression testing."
source_type: "skill"
source_file: "skills/snapshot-testing.md"
---

# snapshot-testing

Migrated from `skills/snapshot-testing.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Snapshot Testing

Component snapshot and visual regression testing.

## React Native Snapshots

```typescript
import { render } from '@testing-library/react-native'
import { Button } from './Button'

describe('Button', () => {
  it('renders correctly', () => {
    const { toJSON } = render(
      <Button title="Press me" onPress={() => {}} />
    )
    expect(toJSON()).toMatchSnapshot()
  })

  it('renders disabled state', () => {
    const { toJSON } = render(
      <Button title="Press me" disabled onPress={() => {}} />
    )
    expect(toJSON()).toMatchSnapshot()
  })
})
```

## Inline Snapshots

```typescript
it('formats date correctly', () => {
  const result = formatDate(new Date('2024-01-15'))
  expect(result).toMatchInlineSnapshot(`"January 15, 2024"`)
})

it('renders card', () => {
  const { toJSON } = render(<Card title="Test" />)
  expect(toJSON()).toMatchInlineSnapshot(`
    <View style={{ padding: 16 }}>
      <Text>Test</Text>
    </View>
  `)
})
```

## Flutter Golden Tests

```dart
void main() {
  testWidgets('Button golden test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyButton(label: 'Press me'),
        ),
      ),
    );

    await expectLater(
      find.byType(MyButton),
      matchesGoldenFile('goldens/button.png'),
    );
  });
}

// Update goldens: flutter test --update-goldens
```

## Snapshot Best Practices

```typescript
// Use snapshot serializers for cleaner output
expect.addSnapshotSerializer({
  test: (val) => val && val.testID,
  print: (val, serialize) => serialize({ ...val, testID: '[testID]' }),
})

// Keep snapshots small and focused
it('renders header', () => {
  const { getByTestId } = render(<Screen />)
  expect(getByTestId('header')).toMatchSnapshot()
})
```

## When to Use Snapshots

```markdown
Good for:
✅ Component structure verification
✅ Detecting unintended changes
✅ API response shapes
✅ Configuration objects

Avoid for:
❌ Highly dynamic content
❌ Large component trees
❌ Frequently changing components
```

## Best Practices

- Review snapshot changes carefully
- Keep snapshots small and focused
- Use inline snapshots for small outputs
- Update intentionally, not blindly
