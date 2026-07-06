---
name: "blueprint-onboarding-flow"
description: "Multi-step onboarding with pagination, skip, permission requests, and completion tracking."
source_type: "blueprint"
source_file: "skills/blueprints/onboarding-flow.md"
---

# blueprint-onboarding-flow

Migrated from `skills/blueprints/onboarding-flow.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Blueprint: Onboarding Flow

Multi-step onboarding with pagination, skip, permission requests, and completion tracking.

## File Manifest

```markdown
# React Native (TypeScript)
src/
  screens/onboarding/
    OnboardingScreen.tsx
    OnboardingPage.tsx
    PermissionsPage.tsx
  hooks/
    useOnboarding.ts
  components/onboarding/
    PageIndicator.tsx
    OnboardingButton.tsx
  __tests__/
    useOnboarding.test.ts
    OnboardingScreen.test.tsx

# Flutter (Dart)
lib/
  features/onboarding/
    screens/
      onboarding_screen.dart
      onboarding_page.dart
      permissions_page.dart
    providers/
      onboarding_provider.dart
    widgets/
      page_indicator.dart
      onboarding_button.dart
test/
  features/onboarding/
    onboarding_provider_test.dart
    onboarding_screen_test.dart
```

## React Native Implementation

### Onboarding Screen
```tsx
// src/screens/onboarding/OnboardingScreen.tsx
import { useRef, useState, useCallback } from 'react';
import { View, FlatList, Dimensions, useWindowDimensions } from 'react-native';
import Animated, { useAnimatedScrollHandler, useSharedValue } from 'react-native-reanimated';
import { useOnboarding } from '../../hooks/useOnboarding';
import { OnboardingPage } from './OnboardingPage';
import { PermissionsPage } from './PermissionsPage';
import { PageIndicator } from '../../components/onboarding/PageIndicator';
import { OnboardingButton } from '../../components/onboarding/OnboardingButton';

const AnimatedFlatList = Animated.createAnimatedComponent(FlatList);

const pages = [
  {
    id: 'welcome',
    title: 'Welcome to MyApp',
    description: 'Your all-in-one solution for staying organized',
    image: require('../../../assets/onboarding/welcome.png'),
  },
  {
    id: 'features',
    title: 'Powerful Features',
    description: 'Track tasks, set reminders, and collaborate with your team',
    image: require('../../../assets/onboarding/features.png'),
  },
  {
    id: 'sync',
    title: 'Sync Everywhere',
    description: 'Your data stays in sync across all your devices',
    image: require('../../../assets/onboarding/sync.png'),
  },
  { id: 'permissions', type: 'permissions' },
];

export function OnboardingScreen() {
  const flatListRef = useRef<FlatList>(null);
  const [currentIndex, setCurrentIndex] = useState(0);
  const scrollX = useSharedValue(0);
  const { width } = useWindowDimensions();
  const { completeOnboarding } = useOnboarding();

  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => { scrollX.value = event.contentOffset.x; },
  });

  const goToNext = useCallback(() => {
    if (currentIndex < pages.length - 1) {
      flatListRef.current?.scrollToIndex({ index: currentIndex + 1 });
      setCurrentIndex(currentIndex + 1);
    } else {
      completeOnboarding();
    }
  }, [currentIndex, completeOnboarding]);

  const skip = useCallback(() => {
    completeOnboarding();
  }, [completeOnboarding]);

  const renderItem = useCallback(({ item }: { item: typeof pages[0] }) => {
    if (item.type === 'permissions') {
      return <PermissionsPage width={width} />;
    }
    return (
      <OnboardingPage
        title={item.title}
        description={item.description}
        image={item.image}
        width={width}
      />
    );
  }, [width]);

  const isLastPage = currentIndex === pages.length - 1;

  return (
    <View style={styles.container}>
      <AnimatedFlatList
        ref={flatListRef}
        data={pages}
        renderItem={renderItem}
        keyExtractor={(item) => item.id}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onScroll={scrollHandler}
        scrollEventThrottle={16}
        onMomentumScrollEnd={(e) => {
          setCurrentIndex(Math.round(e.nativeEvent.contentOffset.x / width));
        }}
        accessibilityRole="adjustable"
        accessibilityLabel={`Onboarding step ${currentIndex + 1} of ${pages.length}`}
      />

      <View style={styles.footer}>
        <PageIndicator count={pages.length} scrollX={scrollX} width={width} />

        <View style={styles.buttons}>
          {!isLastPage && (
            <OnboardingButton
              label="Skip"
              variant="text"
              onPress={skip}
              accessibilityHint="Skip onboarding and go to the app"
            />
          )}
          <OnboardingButton
            label={isLastPage ? 'Get Started' : 'Next'}
            variant="primary"
            onPress={goToNext}
            accessibilityHint={isLastPage ? 'Complete onboarding' : 'Go to next step'}
          />
        </View>
      </View>
    </View>
  );
}
```

### Onboarding Hook
```typescript
// src/hooks/useOnboarding.ts
import { useCallback } from 'react';
import { useMMKVBoolean } from 'react-native-mmkv';

export function useOnboarding() {
  const [completed = false, setCompleted] = useMMKVBoolean('onboarding_completed');

  const completeOnboarding = useCallback(() => {
    setCompleted(true);
  }, [setCompleted]);

  const resetOnboarding = useCallback(() => {
    setCompleted(false);
  }, [setCompleted]);

  return { completed, completeOnboarding, resetOnboarding };
}
```

## Flutter Implementation

### Onboarding Screen
```dart
// lib/features/onboarding/screens/onboarding_screen.dart
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPageData(
      title: 'Welcome to MyApp',
      description: 'Your all-in-one solution for staying organized',
      asset: 'assets/onboarding/welcome.svg',
    ),
    OnboardingPageData(
      title: 'Powerful Features',
      description: 'Track tasks, set reminders, and collaborate with your team',
      asset: 'assets/onboarding/features.svg',
    ),
    OnboardingPageData(
      title: 'Sync Everywhere',
      description: 'Your data stays in sync across all your devices',
      asset: 'assets/onboarding/sync.svg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length; // +1 for permissions

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  ..._pages.map((p) => OnboardingPage(data: p)),
                  const PermissionsPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  PageIndicator(
                    count: _pages.length + 1,
                    current: _currentPage,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isLast)
                        TextButton(
                          onPressed: _complete,
                          child: const Text('Skip'),
                        )
                      else
                        const SizedBox(),
                      FilledButton(
                        onPressed: isLast ? _complete : _next,
                        child: Text(isLast ? 'Get Started' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _complete() {
    ref.read(onboardingProvider.notifier).complete();
    context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Tests

```typescript
describe('useOnboarding', () => {
  it('starts as not completed', () => {
    const { result } = renderHook(() => useOnboarding());
    expect(result.current.completed).toBe(false);
  });

  it('marks onboarding as completed', () => {
    const { result } = renderHook(() => useOnboarding());
    act(() => { result.current.completeOnboarding(); });
    expect(result.current.completed).toBe(true);
  });

  it('can reset onboarding', () => {
    const { result } = renderHook(() => useOnboarding());
    act(() => { result.current.completeOnboarding(); });
    act(() => { result.current.resetOnboarding(); });
    expect(result.current.completed).toBe(false);
  });
});
```

## Accessibility Checklist

- [x] Page changes announced to screen readers with step count
- [x] Skip button available on all pages except last
- [x] Permission requests explain why each permission is needed
- [x] Animations respect `reduceMotion` / `disableAnimations` preference
- [x] Page indicator conveys position to screen readers
- [x] All images have descriptive alt text
