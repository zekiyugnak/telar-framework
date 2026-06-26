---
id: flutter-animations
category: skill
tags: [animations, implicit, explicit, hero, rive, animation-controller]
capabilities:
  - Implicit animations
  - Explicit animations with controllers
  - Hero transitions
  - Rive animations
useWhen:
  - Adding animations to Flutter apps
  - Creating custom animations
  - Implementing page transitions
---

# Flutter Animations

Animation patterns from simple to complex.

## Implicit Animations

```dart
// AnimatedContainer
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: expanded ? 200 : 100,
  height: expanded ? 200 : 100,
  decoration: BoxDecoration(
    color: expanded ? Colors.blue : Colors.red,
    borderRadius: BorderRadius.circular(expanded ? 32 : 8),
  ),
  child: content,
)

// AnimatedOpacity
AnimatedOpacity(
  opacity: visible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 200),
  child: content,
)

// AnimatedSwitcher
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Text(
    '$count',
    key: ValueKey(count),
  ),
)
```

## Explicit Animations

```dart
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
      child: const CircleAvatar(radius: 10),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## Hero Animations

```dart
// Source
Hero(
  tag: 'avatar-${user.id}',
  child: CircleAvatar(backgroundImage: NetworkImage(user.avatar)),
)

// Destination
Hero(
  tag: 'avatar-${user.id}',
  child: Image.network(user.avatar, width: 200),
)
```

## Staggered Animations

```dart
SlideTransition(
  position: Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: controller,
    curve: Interval(0.0, 0.5, curve: Curves.easeOut),
  )),
  child: child,
)
```

## Best Practices

- Use implicit animations for simple cases
- Dispose controllers properly
- Use vsync with TickerProviderStateMixin
- Test animations on low-end devices
