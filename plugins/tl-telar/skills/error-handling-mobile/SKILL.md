---
name: "error-handling-mobile"
description: "An unhandled promise rejection or uncaught exception crashes the entire app, forcing the user to restart and lose in-progress work. This skill covers error boundaries, global handlers, crash reporting integration, and gr"
source_type: "skill"
source_file: "skills/error-handling-mobile.md"
---

# error-handling-mobile

Migrated from `skills/error-handling-mobile.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Prevent App Crashes with Layered Error Handling and Graceful Degradation

An unhandled promise rejection or uncaught exception crashes the entire app, forcing the user to restart and lose in-progress work. This skill covers error boundaries, global handlers, crash reporting integration, and graceful degradation so errors are contained, reported, and presented humanely.

## Problem

A single unhandled error in any component or async call crashes the entire app.

```typescript
// BAD: No error boundary - one component crash kills the whole app
function App() {
  return (
    <NavigationContainer>
      {/* If ProductList throws, the entire app white-screens */}
      <ProductList />
      <CartButton />
      <ProfileMenu />
    </NavigationContainer>
  );
}

// BAD: Unhandled promise rejection in async operation
function ProductList() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    // This promise rejection is unhandled if the API fails
    // React Native will show a red screen in dev and crash in production
    fetch('/api/products')
      .then((res) => res.json())
      .then((data) => setProducts(data));
    // No .catch() - unhandled promise rejection
  }, []);

  // No null check - crashes if products is undefined due to error
  return (
    <FlatList
      data={products}
      renderItem={({ item }) => (
        <Text>{item.name} - ${item.price.toFixed(2)}</Text>
        // Crashes if price is null/undefined: "Cannot read property toFixed of null"
      )}
    />
  );
}

// BAD: Generic error messages that help nobody
function handleError(error: any) {
  Alert.alert('Error', error.message);
  // User sees: "TypeError: Network request failed"
  // or: "SyntaxError: Unexpected token < in JSON at position 0"
  // These messages are meaningless to users
}
```

## Solution

### 1. React Native Error Boundary with Fallback UI

```typescript
// GOOD: Granular error boundaries that isolate failures

import React, { Component, ErrorInfo, ReactNode } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Image } from 'react-native';
import * as Sentry from '@sentry/react-native';

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
  level: 'screen' | 'section' | 'widget';
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    // Report to crash analytics
    Sentry.captureException(error, {
      contexts: {
        react: { componentStack: errorInfo.componentStack },
      },
      tags: {
        boundary_level: this.props.level,
      },
    });

    this.props.onError?.(error, errorInfo);
  }

  handleRetry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;

      // Different fallback UI based on severity level
      switch (this.props.level) {
        case 'screen':
          return (
            <View style={styles.screenError}>
              <Image source={require('./assets/error-illustration.png')} />
              <Text style={styles.title}>Something went wrong</Text>
              <Text style={styles.message}>
                We hit an unexpected problem. Please try again.
              </Text>
              <TouchableOpacity style={styles.retryButton} onPress={this.handleRetry}>
                <Text style={styles.retryText}>Try Again</Text>
              </TouchableOpacity>
            </View>
          );
        case 'section':
          return (
            <View style={styles.sectionError}>
              <Text style={styles.sectionMessage}>
                This section could not load.
              </Text>
              <TouchableOpacity onPress={this.handleRetry}>
                <Text style={styles.retryLink}>Tap to retry</Text>
              </TouchableOpacity>
            </View>
          );
        case 'widget':
          // Widgets fail silently - show nothing rather than break the page
          return null;
      }
    }

    return this.props.children;
  }
}

// GOOD: Apply boundaries at multiple levels for granular isolation
function App() {
  return (
    <ErrorBoundary level="screen">
      <NavigationContainer>
        <HomeScreen />
      </NavigationContainer>
    </ErrorBoundary>
  );
}

function HomeScreen() {
  return (
    <View>
      {/* If recommendations crash, the rest of the screen still works */}
      <ErrorBoundary level="section">
        <RecommendationCarousel />
      </ErrorBoundary>

      {/* Product list has its own boundary */}
      <ErrorBoundary level="section">
        <ProductList />
      </ErrorBoundary>

      {/* Promotional widget fails silently */}
      <ErrorBoundary level="widget">
        <PromoWidget />
      </ErrorBoundary>
    </View>
  );
}
```

### 2. Global Unhandled Error Handlers

```typescript
// GOOD: Catch everything Error Boundaries cannot (async errors, native errors)

import * as Sentry from '@sentry/react-native';

// Initialize crash reporting FIRST, before any other code
Sentry.init({
  dsn: 'https://examplePublicKey@o0.ingest.sentry.io/0',
  tracesSampleRate: 0.2,     // Sample 20% of transactions for performance
  enableAutoSessionTracking: true,
  attachStacktrace: true,
  environment: __DEV__ ? 'development' : 'production',
  // Filter noisy errors that are not actionable
  beforeSend(event) {
    // Ignore network errors from user going offline
    if (event.exception?.values?.[0]?.value?.includes('Network request failed')) {
      return null;
    }
    return event;
  },
});

// Catch unhandled JS promise rejections
// This is the #1 source of production crashes in React Native
if (!__DEV__) {
  const originalHandler = global.ErrorUtils?.getGlobalHandler();

  global.ErrorUtils?.setGlobalHandler((error: Error, isFatal: boolean) => {
    Sentry.captureException(error, {
      tags: { fatal: String(isFatal), handler: 'global' },
    });

    // Call original handler to maintain default behavior
    originalHandler?.(error, isFatal);
  });
}

// Catch unhandled promise rejections explicitly
const tracking = require('promise/setimmediate/rejection-tracking');
tracking.enable({
  allRejections: true,
  onUnhandled: (id: number, error: Error) => {
    Sentry.captureException(error, {
      tags: { type: 'unhandled_promise', promise_id: String(id) },
    });
  },
  onHandled: () => {},
});
```

### 3. Flutter Error Handling

```dart
// GOOD: Comprehensive Flutter error handling

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Catch Flutter framework errors (widget build, layout, painting)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // Show in debug mode
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // 2. Catch errors in the platform dispatcher (engine-level errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: true,
        reason: 'PlatformDispatcher error',
      );
      return true; // Handled
    };

    runApp(const MyApp());
  }, (error, stackTrace) {
    // 3. Catch all other Dart errors (async errors, isolate errors)
    FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: false,
      reason: 'runZonedGuarded error',
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 4. Custom error widget instead of red/grey screen of death
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return _AppErrorWidget(details: details);
        };
        return child!;
      },
      home: const HomeScreen(),
    );
  }
}

class _AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (kDebugMode)
            Text(
              details.exceptionAsString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
```

### 4. Network Error Classification and User-Friendly Messages

```typescript
// GOOD: Classify errors and present actionable messages to users

enum NetworkErrorType {
  OFFLINE = 'OFFLINE',
  TIMEOUT = 'TIMEOUT',
  SERVER_ERROR = 'SERVER_ERROR',
  AUTH_EXPIRED = 'AUTH_EXPIRED',
  RATE_LIMITED = 'RATE_LIMITED',
  NOT_FOUND = 'NOT_FOUND',
  VALIDATION = 'VALIDATION',
  UNKNOWN = 'UNKNOWN',
}

interface ClassifiedError {
  type: NetworkErrorType;
  userMessage: string;
  technicalMessage: string;
  isRetryable: boolean;
  suggestedAction: 'retry' | 'login' | 'wait' | 'contact_support' | 'none';
}

function classifyNetworkError(error: any): ClassifiedError {
  // Offline / DNS failure
  if (
    error instanceof TypeError &&
    error.message.includes('Network request failed')
  ) {
    return {
      type: NetworkErrorType.OFFLINE,
      userMessage: 'No internet connection. Check your network and try again.',
      technicalMessage: error.message,
      isRetryable: true,
      suggestedAction: 'retry',
    };
  }

  // Timeout
  if (error.name === 'AbortError' || error.message?.includes('timeout')) {
    return {
      type: NetworkErrorType.TIMEOUT,
      userMessage: 'Request timed out. Please try again.',
      technicalMessage: error.message,
      isRetryable: true,
      suggestedAction: 'retry',
    };
  }

  const status = error.status || error.response?.status;

  switch (status) {
    case 401:
      return {
        type: NetworkErrorType.AUTH_EXPIRED,
        userMessage: 'Your session has expired. Please sign in again.',
        technicalMessage: `HTTP 401: ${error.message}`,
        isRetryable: false,
        suggestedAction: 'login',
      };

    case 403:
      return {
        type: NetworkErrorType.AUTH_EXPIRED,
        userMessage: 'You do not have permission to perform this action.',
        technicalMessage: `HTTP 403: ${error.message}`,
        isRetryable: false,
        suggestedAction: 'none',
      };

    case 404:
      return {
        type: NetworkErrorType.NOT_FOUND,
        userMessage: 'The requested content was not found.',
        technicalMessage: `HTTP 404: ${error.message}`,
        isRetryable: false,
        suggestedAction: 'none',
      };

    case 422:
      return {
        type: NetworkErrorType.VALIDATION,
        userMessage: error.response?.data?.message || 'Please check your input and try again.',
        technicalMessage: `HTTP 422: ${JSON.stringify(error.response?.data)}`,
        isRetryable: false,
        suggestedAction: 'none',
      };

    case 429:
      return {
        type: NetworkErrorType.RATE_LIMITED,
        userMessage: 'Too many requests. Please wait a moment and try again.',
        technicalMessage: `HTTP 429: Rate limited`,
        isRetryable: true,
        suggestedAction: 'wait',
      };

    case 500: case 502: case 503: case 504:
      return {
        type: NetworkErrorType.SERVER_ERROR,
        userMessage: 'Our servers are having trouble. Please try again in a few minutes.',
        technicalMessage: `HTTP ${status}: ${error.message}`,
        isRetryable: true,
        suggestedAction: 'retry',
      };

    default:
      return {
        type: NetworkErrorType.UNKNOWN,
        userMessage: 'Something went wrong. Please try again.',
        technicalMessage: error.message || 'Unknown error',
        isRetryable: true,
        suggestedAction: 'retry',
      };
  }
}

// GOOD: Error display component with appropriate actions
function NetworkErrorView({ error, onRetry }: { error: any; onRetry: () => void }) {
  const classified = classifyNetworkError(error);
  const navigation = useNavigation();

  return (
    <View style={styles.errorContainer}>
      <ErrorIcon type={classified.type} />
      <Text style={styles.errorMessage}>{classified.userMessage}</Text>

      {classified.suggestedAction === 'retry' && (
        <TouchableOpacity style={styles.retryButton} onPress={onRetry}>
          <Text style={styles.retryText}>Try Again</Text>
        </TouchableOpacity>
      )}

      {classified.suggestedAction === 'login' && (
        <TouchableOpacity
          style={styles.loginButton}
          onPress={() => navigation.navigate('Login')}
        >
          <Text style={styles.loginText}>Sign In</Text>
        </TouchableOpacity>
      )}

      {classified.suggestedAction === 'wait' && (
        <Text style={styles.waitText}>Please wait a moment and try again.</Text>
      )}
    </View>
  );
}
```

### 5. Graceful Degradation Patterns

```typescript
// GOOD: Degrade gracefully instead of crashing

// Pattern 1: Safe data access with fallbacks
function ProductCard({ product }: { product: any }) {
  // Safely access nested properties with fallbacks
  const name = product?.name ?? 'Untitled Product';
  const price = typeof product?.price === 'number'
    ? `$${product.price.toFixed(2)}`
    : 'Price unavailable';
  const imageUrl = product?.imageUrl;

  return (
    <View style={styles.card}>
      {imageUrl ? (
        <Image
          source={{ uri: imageUrl }}
          style={styles.productImage}
          // Show placeholder on load failure instead of crashing
          onError={() => {/* Silently fall back to placeholder */}}
          defaultSource={require('./assets/product-placeholder.png')}
        />
      ) : (
        <View style={styles.imagePlaceholder}>
          <PlaceholderIcon />
        </View>
      )}
      <Text style={styles.name}>{name}</Text>
      <Text style={styles.price}>{price}</Text>
    </View>
  );
}

// Pattern 2: Feature flags for degraded mode
function useFeatureWithFallback<T>(
  fetcher: () => Promise<T>,
  fallback: T,
  featureName: string,
): { data: T; isUsingFallback: boolean } {
  const [data, setData] = useState<T>(fallback);
  const [isUsingFallback, setIsUsingFallback] = useState(false);

  useEffect(() => {
    let cancelled = false;
    fetcher()
      .then((result) => {
        if (!cancelled) setData(result);
      })
      .catch((error) => {
        Sentry.captureException(error, {
          tags: { feature: featureName, degraded: 'true' },
        });
        if (!cancelled) {
          setIsUsingFallback(true);
          // Keep using fallback data - do not crash
        }
      });
    return () => { cancelled = true; };
  }, []);

  return { data, isUsingFallback };
}

// Usage: recommendations degrade to static list if API fails
function RecommendationSection() {
  const { data: recommendations, isUsingFallback } = useFeatureWithFallback(
    () => api.getRecommendations(),
    STATIC_DEFAULT_RECOMMENDATIONS,
    'recommendations',
  );

  return (
    <View>
      {isUsingFallback && (
        <Text style={styles.degradedBanner}>Showing popular items</Text>
      )}
      <FlatList data={recommendations} renderItem={renderProduct} />
    </View>
  );
}

// Pattern 3: Async error wrapper for any async function
function withErrorHandling<TArgs extends any[], TReturn>(
  fn: (...args: TArgs) => Promise<TReturn>,
  context: string,
): (...args: TArgs) => Promise<TReturn | null> {
  return async (...args: TArgs) => {
    try {
      return await fn(...args);
    } catch (error) {
      Sentry.captureException(error, {
        tags: { context },
        extra: { args: JSON.stringify(args) },
      });
      return null;
    }
  };
}

// Usage: wrapping any async call with automatic error capture
const safeLoadProfile = withErrorHandling(loadUserProfile, 'profile_load');
const profile = await safeLoadProfile(userId); // Returns null on failure
```

### 6. Crash Reporting Integration

```typescript
// GOOD: Sentry setup with breadcrumbs and user context

import * as Sentry from '@sentry/react-native';
import { NavigationContainerRef } from '@react-navigation/native';

// Navigation breadcrumbs - track where the user was before the crash
const navigationRef = React.createRef<NavigationContainerRef<any>>();

const routingInstrumentation = new Sentry.ReactNavigationInstrumentation();

Sentry.init({
  dsn: 'https://examplePublicKey@o0.ingest.sentry.io/0',
  integrations: [
    new Sentry.ReactNativeTracing({
      routingInstrumentation,
    }),
  ],
});

// Set user context after authentication
function onLogin(user: { id: string; email: string }) {
  Sentry.setUser({ id: user.id, email: user.email });
}

function onLogout() {
  Sentry.setUser(null);
}

// Add custom breadcrumbs for important actions
function onPurchaseAttempt(productId: string) {
  Sentry.addBreadcrumb({
    category: 'purchase',
    message: `Attempting purchase of ${productId}`,
    level: 'info',
  });
}
```

```dart
// GOOD: Firebase Crashlytics setup in Flutter
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Set user ID for crash correlation
void onLogin(String userId) {
  FirebaseCrashlytics.instance.setUserIdentifier(userId);
}

// Add custom keys for debugging context
void setAppContext(String screen, String action) {
  FirebaseCrashlytics.instance.setCustomKey('current_screen', screen);
  FirebaseCrashlytics.instance.setCustomKey('last_action', action);
}

// Log non-fatal errors that should be tracked but not crash
Future<void> loadData() async {
  try {
    await api.fetchData();
  } catch (e, stack) {
    FirebaseCrashlytics.instance.recordError(
      e,
      stack,
      reason: 'Data load failed',
      fatal: false,
    );
    // Show fallback UI instead of crashing
  }
}
```

## Why This Works

- **Error Boundaries catch synchronous render errors** that would otherwise unmount the entire React tree. By placing boundaries at screen, section, and widget levels, a crash in a promotional widget does not take down the navigation or product list.
- **Global error handlers catch async errors** that Error Boundaries cannot see (promise rejections, setTimeout callbacks, event handlers). Together they form a complete safety net.
- **Error classification** separates actionable errors (retry, re-login) from non-actionable ones (server down), giving users clear next steps instead of technical gibberish.
- **Graceful degradation** keeps the app usable even when individual features fail. A failed recommendations API returns a static fallback list rather than crashing the entire home screen.
- **Crash reporting with breadcrumbs** provides the full context (navigation path, user actions, device state) needed to reproduce and fix the crash, not just a stack trace.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- React Native's `global.ErrorUtils` does not catch all native-level crashes (e.g., out-of-memory kills). Sentry's native integration catches these via signal handlers.
- iOS will terminate apps that take too long to respond to system events. Wrap all `AppDelegate` lifecycle methods in try-catch.

**Android:**
- `Thread.setDefaultUncaughtExceptionHandler` conflicts with some crash reporting SDKs. Use only one crash reporter or chain handlers explicitly.
- ANR (Application Not Responding) events are not exceptions. Sentry and Crashlytics detect these separately via watchdog timers.

**Flutter:**
- `FlutterError.onError` only catches errors in the Flutter framework. Dart isolate errors and platform channel errors require separate handling via `PlatformDispatcher.instance.onError`.
- The `ErrorWidget.builder` only affects debug mode by default. Override it explicitly for release mode as shown above.

### Common Mistakes

- **Catching errors and swallowing them silently** - `catch (e) {}` hides bugs. Always log to crash reporting even if you handle the error gracefully.
- **Showing technical error messages to users** - `"SyntaxError: Unexpected token <"` means the API returned HTML instead of JSON. Show "Server error, please try again" instead.
- **Wrapping the entire app in one Error Boundary** - a crash anywhere resets the whole app. Use nested boundaries for granular isolation.
- **Not clearing error state on retry** - calling `resetErrorBoundary()` or setting `hasError: false` must happen to re-render the children.
- **Logging PII in crash reports** - do not attach full request bodies or user messages to crash reports. Redact sensitive fields.

## Verification

```bash
# Test error boundary by intentionally throwing in a component
# In development mode, verify the fallback UI appears instead of red screen

# Test global handler by triggering an unhandled promise rejection
# setTimeout(() => { Promise.reject(new Error('test')) }, 1000)

# Verify crash reports arrive in Sentry/Crashlytics dashboard
# Use Sentry's test command:
npx @sentry/cli send-event -m "Test event from CI"

# Check for unhandled promise warnings in metro logs
npx react-native start --verbose 2>&1 | grep -i "unhandled"
```

- [ ] Error Boundary renders fallback UI when a child component throws
- [ ] Unhandled promise rejections are captured (not silently swallowed)
- [ ] Crash reports appear in Sentry/Crashlytics with correct stack traces
- [ ] Network errors show user-friendly messages with appropriate actions
- [ ] App remains usable when a non-critical feature fails (graceful degradation)
- [ ] Error state can be reset with retry button (Error Boundary re-renders children)
- [ ] No PII is included in crash reports

## References

- [React Error Boundaries](https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary)
- [Sentry React Native SDK](https://docs.sentry.io/platforms/react-native/)
- [Firebase Crashlytics Flutter](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter)
- [Flutter Error Handling](https://docs.flutter.dev/testing/errors)
- [react-error-boundary](https://github.com/bvaughn/react-error-boundary)
- [OWASP Mobile Error Handling](https://owasp.org/www-project-mobile-top-10/)
