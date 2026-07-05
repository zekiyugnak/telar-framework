---
id: rn-animations
category: skill
tags: [reanimated, gesture-handler, lottie, animations, transitions]
capabilities:
  - Reanimated 3 worklet animations
  - Gesture Handler integration
  - Lottie animations
  - Shared element transitions
useWhen:
  - Creating smooth animations
  - Implementing gesture-driven UI
  - Adding Lottie animations
---

# React Native Animations

Animation patterns using Reanimated 3 and Gesture Handler.

## Reanimated Basics

```typescript
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  interpolate,
} from 'react-native-reanimated'

function AnimatedBox() {
  const scale = useSharedValue(1)

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }))

  const handlePress = () => {
    scale.value = withSpring(scale.value === 1 ? 1.2 : 1, {
      damping: 15,
      stiffness: 150,
    })
  }

  return (
    <Pressable onPress={handlePress}>
      <Animated.View style={[styles.box, animatedStyle]} />
    </Pressable>
  )
}
```

## Gesture-Driven Animation

```typescript
import { Gesture, GestureDetector } from 'react-native-gesture-handler'

function DraggableCard() {
  const translateX = useSharedValue(0)
  const translateY = useSharedValue(0)

  const panGesture = Gesture.Pan()
    .onUpdate((e) => {
      translateX.value = e.translationX
      translateY.value = e.translationY
    })
    .onEnd(() => {
      translateX.value = withSpring(0)
      translateY.value = withSpring(0)
    })

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
    ],
  }))

  return (
    <GestureDetector gesture={panGesture}>
      <Animated.View style={[styles.card, animatedStyle]} />
    </GestureDetector>
  )
}
```

## Lottie

```typescript
import LottieView from 'lottie-react-native'

<LottieView
  source={require('./animation.json')}
  autoPlay
  loop
  style={{ width: 200, height: 200 }}
/>
```

## Best Practices

- Use worklets for complex animations
- Prefer spring over timing for natural feel
- Test on low-end devices
- Clean up gestures on unmount
