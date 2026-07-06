---
name: "memory-management"
description: "Managing memory effectively in mobile applications."
source_type: "skill"
source_file: "skills/memory-management.md"
---

# memory-management

Migrated from `skills/memory-management.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Memory Management

Managing memory effectively in mobile applications.

## React Native Memory Leaks

```typescript
// Common leak: Unsubscribed listeners
function Component() {
  useEffect(() => {
    const subscription = eventEmitter.addListener('event', handler)

    // ✅ Always cleanup
    return () => subscription.remove()
  }, [])
}

// Common leak: Async operations after unmount
function Component() {
  const [data, setData] = useState(null)
  const isMounted = useRef(true)

  useEffect(() => {
    fetchData().then(result => {
      // ✅ Check if mounted before setting state
      if (isMounted.current) {
        setData(result)
      }
    })

    return () => {
      isMounted.current = false
    }
  }, [])
}

// Better: Use abort controller
function Component() {
  useEffect(() => {
    const controller = new AbortController()

    fetch(url, { signal: controller.signal })
      .then(setData)
      .catch(err => {
        if (err.name !== 'AbortError') throw err
      })

    return () => controller.abort()
  }, [])
}
```

## Image Memory Management

```typescript
// Clear image cache when memory pressure
import FastImage from 'react-native-fast-image'
import { AppState } from 'react-native'

useEffect(() => {
  const subscription = AppState.addEventListener('memoryWarning', () => {
    FastImage.clearMemoryCache()
  })
  return () => subscription.remove()
}, [])
```

## Flutter Memory Management

```dart
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _subscription = stream.listen(handleData);
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    // ✅ Always dispose subscriptions and controllers
    _subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}

// Use AutoDispose with Riverpod
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  void build() {
    // Automatically disposed when no longer used
    ref.onDispose(() => cleanup());
  }
}
```

## Best Practices

- Always cleanup subscriptions and listeners
- Cancel async operations on unmount
- Use weak references where appropriate
- Profile memory usage regularly
