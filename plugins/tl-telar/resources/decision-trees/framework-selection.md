# Framework Selection Decision Tree

Choose between React Native, Flutter, and Native development.

## Quick Decision

```
START
├── Need maximum native performance (games, AR, complex animations)?
│   └── YES → Native (Swift/Kotlin)
├── Team primarily knows JavaScript/TypeScript?
│   ├── YES → React Native
│   └── Willing to learn Dart?
│       ├── YES → Consider Flutter
│       └── NO → React Native
├── Need pixel-perfect custom UI across platforms?
│   └── YES → Flutter (own rendering engine)
├── Heavy use of platform-specific APIs (HealthKit, NFC, etc.)?
│   └── YES → Native or React Native with native modules
├── Need web + mobile from single codebase?
│   ├── React Native Web is sufficient → React Native
│   └── Need full web parity → Flutter Web
└── DEFAULT → React Native (larger ecosystem, more hiring options)
```

## Detailed Comparison

| Factor | React Native | Flutter | Native |
|--------|-------------|---------|--------|
| Language | TypeScript | Dart | Swift/Kotlin |
| Rendering | Native components | Own engine (Skia/Impeller) | Native |
| Hot Reload | Yes (Fast Refresh) | Yes (stateful) | Limited |
| Bundle Size | ~7MB (Hermes) | ~10MB (base) | ~2MB |
| Startup Time | Good (Hermes) | Good (AOT) | Best |
| Ecosystem | npm (massive) | pub.dev (growing) | Platform SDKs |
| Hiring Pool | Large (JS devs) | Growing | Platform-specific |
| Code Sharing | 85-95% | 95-99% | 0% |
| OTA Updates | Yes (EAS/CodePush) | Limited (Shorebird) | No |
| Accessibility | Native a11y APIs | Custom + Semantics | Best (native) |

## When to Choose React Native

- Team has strong JavaScript/TypeScript skills
- Need to share logic with web app (React)
- OTA updates are important (Expo EAS Updates)
- Hiring JavaScript developers is easier for your market
- Existing React web codebase to leverage
- Need Expo managed workflow simplicity

## When to Choose Flutter

- Need pixel-perfect custom UI (own rendering engine)
- Want highest code sharing ratio (95%+)
- Building for mobile + web + desktop from one codebase
- Team is comfortable learning Dart
- Complex animations are core feature
- Google ecosystem integration (Firebase, etc.)

## When to Choose Native

- Performance is absolute priority (games, real-time audio/video)
- Heavy platform API usage (HealthKit, ARKit, NFC, Widgets)
- Small app with one-platform focus
- Team already has Swift/Kotlin expertise
- Need latest platform features on day one
- App Store review concerns (some categories prefer native)

## Hybrid Approach

Consider native + cross-platform:
- Core app in React Native or Flutter
- Performance-critical screens in native modules
- Platform-specific features via native bridges
- Shared business logic layer
