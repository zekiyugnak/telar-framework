---
name: "render-optimization"
description: "Optimizing rendering performance for smooth 60fps."
source_type: "skill"
source_file: "skills/render-optimization.md"
---

# render-optimization

Migrated from `skills/render-optimization.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Render Optimization

Optimizing rendering performance for smooth 60fps.

## React Native Memoization

```typescript
// Memoize components
const ExpensiveComponent = memo(({ data }) => {
  return <View>{/* expensive render */}</View>
}, (prevProps, nextProps) => {
  // Custom comparison
  return prevProps.data.id === nextProps.data.id
})

// Memoize callbacks
function Parent() {
  const handlePress = useCallback((id) => {
    // handle press
  }, [])

  return <Child onPress={handlePress} />
}

// Memoize computed values
function Component({ items }) {
  const sortedItems = useMemo(() => {
    return [...items].sort((a, b) => a.name.localeCompare(b.name))
  }, [items])
}
```

## Avoiding Re-renders

```typescript
// ❌ Bad - creates new object each render
<Child style={{ flex: 1 }} />

// ✅ Good - stable reference
const styles = StyleSheet.create({ container: { flex: 1 } })
<Child style={styles.container} />

// ❌ Bad - creates new function each render
<Button onPress={() => handlePress(id)} />

// ✅ Good - memoized callback
const handlePress = useCallback(() => {
  // handle
}, [id])
<Button onPress={handlePress} />
```

## State Optimization

```typescript
// Split state to prevent unnecessary renders
// ❌ Bad
const [state, setState] = useState({ user: null, posts: [], loading: false })

// ✅ Good
const [user, setUser] = useState(null)
const [posts, setPosts] = useState([])
const [loading, setLoading] = useState(false)

// Use context splitting
const UserContext = createContext(null)
const PostsContext = createContext([])
```

## Flutter Optimization

```dart
// Use const constructors
const MyWidget({super.key});

// Split widgets for rebuild isolation
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const StaticHeader(), // Won't rebuild
        Consumer<Counter>( // Only this rebuilds
          builder: (_, counter, __) => Text('${counter.value}'),
        ),
      ],
    );
  }
}

// Use RepaintBoundary for heavy widgets
RepaintBoundary(
  child: ExpensiveAnimatedWidget(),
)
```

## Best Practices

- Use React DevTools Profiler to identify re-renders
- Memoize expensive computations
- Keep component state as local as possible
- Split contexts to reduce update scope
