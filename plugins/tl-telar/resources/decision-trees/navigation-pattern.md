# Navigation Pattern Decision Tree

Choose the right navigation structure for your mobile app.

## Primary Navigation Pattern

```
START
├── App has 2-5 top-level sections?
│   └── YES → Bottom Tab Navigation
│       ├── More than 5 sections?
│       │   └── Add "More" tab or use Drawer
│       └── Need to show badge counts?
│           └── YES → Tabs with badge support
├── App is content/utility focused with many sections?
│   └── YES → Drawer Navigation
├── App is linear flow (onboarding, checkout)?
│   └── YES → Stack Navigation only
├── App is single-purpose (camera, calculator)?
│   └── YES → Minimal stack (no tabs/drawer)
└── DEFAULT → Bottom Tabs + Stack per tab
```

## Common Patterns

### 1. Tabs + Stacks (Most Common)
```
NavigationContainer
└── RootStack
    ├── AuthStack (login, signup, forgot password)
    └── MainTabs
        ├── HomeTab → HomeStack (home, detail, ...)
        ├── SearchTab → SearchStack (search, results, ...)
        ├── ProfileTab → ProfileStack (profile, settings, ...)
        └── ...
```
**Use when:** App has 2-5 distinct sections, each with drill-down screens.

### 2. Drawer + Stacks
```
NavigationContainer
└── Drawer
    ├── Home → HomeStack
    ├── Orders → OrderStack
    ├── Settings → SettingsStack
    └── ... (many sections)
```
**Use when:** App has 5+ sections, content-heavy (news, enterprise).

### 3. Auth-Gated Navigation
```
NavigationContainer
└── RootStack
    ├── [not authenticated] → AuthStack
    └── [authenticated] → MainTabs or Drawer
```
**Use when:** Most of the app requires login.

### 4. Modal Overlays
```
RootStack (mode: 'modal')
├── MainFlow (headerShown: false)
│   └── MainTabs → ...
├── CreatePostModal (presentation: 'modal')
├── SettingsModal (presentation: 'fullScreenModal')
└── ImageViewer (presentation: 'transparentModal')
```
**Use when:** Need overlays for creation flows, settings, media viewers.

## Platform Conventions

| Pattern | iOS Convention | Android Convention |
|---------|---------------|-------------------|
| Back navigation | Swipe from left edge | Hardware/gesture back |
| Primary nav | Bottom tabs | Bottom tabs (Material 3) |
| Secondary nav | Tab bar at top | Drawer or top tabs |
| Modals | Card-style, swipe to dismiss | Full screen or bottom sheet |
| Search | Pull-down or search bar in nav | Search icon in app bar |
| Settings | Grouped table view | Preference screen |

## Decision Matrix by App Type

| App Type | Primary | Secondary | Modals |
|----------|---------|-----------|--------|
| Social media | Bottom tabs | Stack push | Create post, stories |
| E-commerce | Bottom tabs | Stack push | Cart, filters |
| Messaging | Bottom tabs | Stack push | New message, media |
| Banking | Bottom tabs | Stack push | Transfer, scanner |
| News/content | Bottom tabs or drawer | Stack push | Article reader |
| Fitness | Bottom tabs | Stack push | Workout player |
| Utility | Minimal stack | - | Settings |

## Deep Linking Considerations

- Every screen should have a URL pattern
- Tab screens: `/home`, `/search`, `/profile`
- Detail screens: `/products/:id`, `/users/:userId`
- Modal screens: handled via query params or separate routes
- Auth screens: redirect to intended destination after login
