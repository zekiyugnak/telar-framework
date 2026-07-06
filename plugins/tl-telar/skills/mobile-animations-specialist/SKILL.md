---
name: "mobile-animations-specialist"
description: "Expert in creating smooth, performant animations for React Native and Flutter applications."
source_type: "agent"
source_file: "agents/mobile-animations-specialist.md"
---

# mobile-animations-specialist

Migrated from `agents/mobile-animations-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Animations Specialist

Expert in creating smooth, performant animations for React Native and Flutter applications.

## React Native Reanimated 3

**Basic Animations:**
```typescript
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  withSequence,
  Easing,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated'

function AnimatedCard() {
  const scale = useSharedValue(1)
  const opacity = useSharedValue(1)

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }))

  const handlePressIn = () => {
    scale.value = withSpring(0.95, {
      damping: 15,
      stiffness: 150,
    })
  }

  const handlePressOut = () => {
    scale.value = withSpring(1)
  }

  return (
    <Pressable onPressIn={handlePressIn} onPressOut={handlePressOut}>
      <Animated.View style={[styles.card, animatedStyle]}>
        <Text>Press me</Text>
      </Animated.View>
    </Pressable>
  )
}
```

**Scroll-Driven Animations:**
```typescript
import { useAnimatedScrollHandler, interpolate } from 'react-native-reanimated'

function ParallaxHeader() {
  const scrollY = useSharedValue(0)

  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollY.value = event.contentOffset.y
    },
  })

  const headerStyle = useAnimatedStyle(() => ({
    height: interpolate(
      scrollY.value,
      [0, 200],
      [300, 100],
      Extrapolation.CLAMP
    ),
    opacity: interpolate(
      scrollY.value,
      [0, 150],
      [1, 0],
      Extrapolation.CLAMP
    ),
  }))

  return (
    <View style={styles.container}>
      <Animated.View style={[styles.header, headerStyle]}>
        <Image source={headerImage} style={StyleSheet.absoluteFill} />
      </Animated.View>
      <Animated.ScrollView onScroll={scrollHandler} scrollEventThrottle={16}>
        {/* Content */}
      </Animated.ScrollView>
    </View>
  )
}
```

## Gesture-Driven Animations

```typescript
import { Gesture, GestureDetector } from 'react-native-gesture-handler'
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  runOnJS,
} from 'react-native-reanimated'

function SwipeableCard({ onSwipe }) {
  const translateX = useSharedValue(0)
  const translateY = useSharedValue(0)
  const rotation = useSharedValue(0)

  const panGesture = Gesture.Pan()
    .onUpdate((event) => {
      translateX.value = event.translationX
      translateY.value = event.translationY
      rotation.value = event.translationX / 20
    })
    .onEnd((event) => {
      const shouldSwipe = Math.abs(event.translationX) > 150

      if (shouldSwipe) {
        const direction = event.translationX > 0 ? 'right' : 'left'
        translateX.value = withSpring(event.translationX > 0 ? 500 : -500)
        runOnJS(onSwipe)(direction)
      } else {
        translateX.value = withSpring(0)
        translateY.value = withSpring(0)
        rotation.value = withSpring(0)
      }
    })

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { rotate: `${rotation.value}deg` },
    ],
  }))

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View style={[styles.card, animatedStyle]}>
        {/* Card content */}
      </Animated.View>
    </GestureDetector>
  )
}
```

## Lottie Animations

```typescript
import LottieView from 'lottie-react-native'
import { useRef } from 'react'

function AnimatedCheckmark({ checked }) {
  const animationRef = useRef<LottieView>(null)

  useEffect(() => {
    if (checked) {
      animationRef.current?.play()
    } else {
      animationRef.current?.reset()
    }
  }, [checked])

  return (
    <LottieView
      ref={animationRef}
      source={require('./checkmark.json')}
      style={{ width: 50, height: 50 }}
      loop={false}
      autoPlay={false}
    />
  )
}

// Interactive Lottie
function LikeButton() {
  const [liked, setLiked] = useState(false)

  return (
    <Pressable onPress={() => setLiked(!liked)}>
      <LottieView
        source={require('./heart.json')}
        progress={liked ? 1 : 0}
        style={{ width: 60, height: 60 }}
      />
    </Pressable>
  )
}
```

## Flutter Animations

```dart
// Implicit animation
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: expanded ? 200 : 100,
  height: expanded ? 200 : 100,
  decoration: BoxDecoration(
    color: expanded ? Colors.blue : Colors.red,
    borderRadius: BorderRadius.circular(expanded ? 16 : 8),
  ),
  child: Center(child: Text('Tap me')),
)

// Explicit animation
class PulsingDot extends StatefulWidget {
  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Best Practices

- **Use worklets** for JS-thread-independent animations
- **Prefer spring animations** for natural-feeling motion
- **Test on low-end devices** to ensure performance
- **Avoid animating layout properties** (width, height) when possible
- **Use `useNativeDriver: true`** for standard Animated API

## Common Pitfalls

- Running animations on JS thread causing jank
- Not cleaning up animation listeners
- Over-animating causing visual noise
- Using expensive interpolations in render
