---
name: "flutter-navigation"
description: "The most common GoRouter bug in production is using `context.push` when `context.go` is needed, or vice versa. `push` adds to the stack; `go` replaces the entire stack based on the URL. Mixing them creates impossible bac"
source_type: "skill"
source_file: "skills/flutter-navigation.md"
---

# flutter-navigation

Migrated from `skills/flutter-navigation.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Fix Broken Back Stacks from Push vs Go Confusion in GoRouter

The most common GoRouter bug in production is using `context.push` when `context.go` is needed, or vice versa. `push` adds to the stack; `go` replaces the entire stack based on the URL. Mixing them creates impossible back-button states where users tap Back and land on screens they never visited. This skill covers GoRouter guards, shell routes, deep linking, and typed routes.

## Problem

Developers treat `push` and `go` as interchangeable, causing broken navigation stacks. Users press Back and see screens they never navigated to, or get trapped in loops.

```dart
// BAD: Using push for top-level navigation between tabs
// This ADDS /settings on top of /home, creating a stack of [/home, /settings]
// When user taps the Settings tab again, another /settings is pushed
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // WRONG: push creates a stack entry
        // Pressing back goes to /home, but user expected to stay on settings
        context.push('/settings');
      },
      child: Text('Go to Settings'),
    );
  }
}

// BAD: Auth redirect that doesn't handle initial location
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => HomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => LoginScreen()),
  ],
  // WRONG: This redirect runs on EVERY navigation, including /login itself
  // Causes infinite redirect loop: /login -> redirect checks -> /login -> ...
  redirect: (context, state) {
    if (!isLoggedIn) return '/login';
    return null; // Missing check: what if user IS logged in and on /login?
  },
);

// BAD: Shell route without proper navigation key handling
// Bottom nav doesn't preserve state when switching tabs
ShellRoute(
  builder: (context, state, child) => ScaffoldWithNav(child: child),
  routes: [
    GoRoute(path: '/home', builder: (_, __) => HomeScreen()),
    GoRoute(path: '/search', builder: (_, __) => SearchScreen()),
  ],
)
```

## Solution

Use `go` for top-level navigation (changing "where you are"), `push` for drilling deeper into a section. Implement proper redirect guards with all edge cases handled. Use `StatefulShellRoute` for tab persistence.

### Router Configuration with Auth Guards

```dart
// GOOD: Complete GoRouter setup with proper auth redirect
// lib/router/app_router.dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authState, // Re-evaluates redirect when auth changes
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      // Not logged in and not on auth route -> redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        // Preserve the intended destination for post-login redirect
        final from = state.matchedLocation;
        return '/auth/login?from=${Uri.encodeComponent(from)}';
      }

      // Logged in but on auth route -> redirect to home
      if (isLoggedIn && isAuthRoute) {
        // Check if there's a saved destination from pre-login
        final from = state.uri.queryParameters['from'];
        return from != null ? Uri.decodeComponent(from) : '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Auth routes (no shell, no bottom nav)
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app with persistent bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Home tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  // Nested route: push within Home tab
                  GoRoute(
                    path: 'post/:postId',
                    builder: (context, state) {
                      final postId = state.pathParameters['postId']!;
                      return PostDetailScreen(postId: postId);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Search tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
                routes: [
                  GoRoute(
                    path: 'results',
                    builder: (context, state) {
                      final query = state.uri.queryParameters['q'] ?? '';
                      return SearchResultsScreen(query: query);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Profile tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}
```

### Scaffold with Persistent Bottom Navigation

```dart
// GOOD: Bottom nav that preserves tab state using StatefulNavigationShell
// lib/widgets/scaffold_with_nav_bar.dart
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // Use goBranch to switch tabs. This uses go semantics
          // (replaces stack) not push semantics (adds to stack)
          navigationShell.goBranch(
            index,
            // Navigate to initial location if tapping current tab
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

### Typed Route Parameters with Code Generation

```dart
// GOOD: Type-safe routes using GoRouterBuilder code generation
// lib/router/routes.dart
import 'package:go_router/go_router.dart';

// Define typed routes - run `dart run build_runner build` to generate
@TypedGoRoute<HomeRoute>(
  path: '/',
  routes: [
    TypedGoRoute<PostDetailRoute>(path: 'post/:postId'),
  ],
)
class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

class PostDetailRoute extends GoRouteData {
  const PostDetailRoute({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PostDetailScreen(postId: postId);
}

// Usage with full type safety - no string paths needed
const PostDetailRoute(postId: 'abc123').go(context); // go semantics
const PostDetailRoute(postId: 'abc123').push(context); // push semantics
```

### Correct Push vs Go Usage

```dart
// GOOD: Understanding when to use push vs go
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // GO: Replaces the entire navigation stack to match the URL
        // Use for: tab switches, logout redirect, top-level navigation
        ElevatedButton(
          onPressed: () => context.go('/search'),
          child: Text('Switch to Search tab'),
        ),

        // PUSH: Adds a new screen on top of the current stack
        // Use for: drilling into detail screens, opening sub-pages
        ElevatedButton(
          onPressed: () => context.push('/post/abc123'),
          child: Text('View post detail'),
        ),

        // PUSH REPLACEMENT: Replaces current screen in stack
        // Use for: wizard flows where Back should skip completed steps
        ElevatedButton(
          onPressed: () => context.pushReplacement('/onboarding/step2'),
          child: Text('Next step'),
        ),
      ],
    );
  }
}
```

## Why This Works

- **`go` rebuilds the stack from the URL**: When you call `context.go('/search')`, GoRouter computes the complete screen stack for that URL. There is no "previous" screen to go back to unless the route definition nests it under a parent. This makes tab switching clean.
- **`push` respects the existing stack**: `context.push('/post/abc123')` pushes PostDetail on top of whatever is currently showing. The Back button pops back to the previous screen. This is correct for detail views.
- **`StatefulShellRoute` preserves tab state**: Unlike plain `ShellRoute`, `StatefulShellRoute.indexedStack` maintains a separate navigation stack for each branch. Switching tabs preserves scroll position and nested navigation within each tab.
- **`refreshListenable` triggers redirect re-evaluation**: When auth state changes, the router re-runs the redirect function. If the user becomes unauthenticated, they are automatically redirected to login without any manual navigation call.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Universal links require Associated Domains entitlement in Xcode and an `apple-app-site-association` file served from your domain.
- The iOS swipe-back gesture works automatically with GoRouter push. Custom transitions using `pageBuilder` may need explicit `CupertinoPage` wrapping to preserve this behavior.

**Android:**
- Deep link intent filters must be in `AndroidManifest.xml` with `autoVerify="true"` for verified App Links.
- The Android system Back button calls `SystemNavigator.pop()` when the last route is popped, which exits the app. GoRouter handles this, but custom `WillPopScope` / `PopScope` wrappers can break this behavior.

### Common Mistakes

- **Using `go` for detail screens**: `context.go('/post/abc123')` from the Home tab destroys the Home tab's stack. The user lands on PostDetail with no Back button. Use `push` instead.
- **Missing redirect loop guard**: Always check if the user is already on the target route before redirecting. Without `isAuthRoute` check, the redirect sends `/login` to `/login` infinitely.
- **Forgetting query parameter encoding**: When saving `from` location in redirect, always use `Uri.encodeComponent`. URLs with special characters like `?q=hello world` break without encoding.
- **Not testing cold start deep links**: A deep link opening the app from a killed state runs the redirect before the route builder. If your auth state is async (loading from storage), the redirect may incorrectly send users to login. Use a splash/loading state.

## Verification

```bash
# Test deep links on Android emulator
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://myapp.com/post/abc123" com.example.myapp

# Test deep links on iOS simulator
xcrun simctl openurl booted "https://myapp.com/post/abc123"

# Run GoRouter debug logging
# Set debugLogDiagnostics: true in GoRouter constructor
# Look for "[GoRouter] going to /path" in console
```

- [ ] Navigate Home -> PostDetail -> switch to Search tab -> switch back to Home tab. Verify PostDetail is still showing (tab state preserved).
- [ ] Call `context.go('/auth/login')` while on a deep screen. Verify entire main stack is cleared.
- [ ] Call `context.push('/post/123')` from Home. Press Back. Verify you return to Home.
- [ ] Kill app. Open deep link to `/post/abc123`. Verify auth redirect saves destination and navigates after login.
- [ ] Rapidly switch tabs 10 times. Verify no duplicate screens or stack corruption.

## References

- [GoRouter Official Docs](https://pub.dev/documentation/go_router/latest/)
- [GoRouter Redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html)
- [StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html)
- [GoRouter Type-safe Routes](https://pub.dev/documentation/go_router/latest/topics/Type-safe%20routes-topic.html)
- [Flutter Deep Linking](https://docs.flutter.dev/ui/navigation/deep-linking)
