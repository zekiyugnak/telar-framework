---
id: snapshot-testing
category: skill
tags: [snapshots, golden-tests, visual-regression, component-testing]
capabilities:
  - Component snapshot testing
  - Golden image tests
  - Visual regression testing
  - Snapshot maintenance
useWhen:
  - Testing component output
  - Detecting UI regressions
  - Setting up golden tests
---

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
