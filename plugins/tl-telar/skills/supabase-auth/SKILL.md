---
name: "supabase-auth"
description: "Supabase JWT tokens expire after 1 hour by default. When multiple API calls detect an expired token simultaneously, each one independently tries to refresh the token. The second refresh attempt uses an already-consumed r"
source_type: "skill"
source_file: "skills/supabase-auth.md"
---

# supabase-auth

Migrated from `skills/supabase-auth.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Fix Token Refresh Race Conditions Causing Random Logouts

Supabase JWT tokens expire after 1 hour by default. When multiple API calls detect an expired token simultaneously, each one independently tries to refresh the token. The second refresh attempt uses an already-consumed refresh token, which Supabase rejects, destroying the session. Users experience random logouts mid-session. This skill covers PKCE flows, race condition prevention, social auth setup, and session persistence for both React Native and Flutter.

## Problem

Multiple concurrent API calls with an expired access token trigger parallel refresh attempts. The first one succeeds and rotates the refresh token. The subsequent attempts fail because they use the now-invalidated old refresh token.

```typescript
// BAD (React Native): Multiple components fetch data on mount simultaneously
// Each detects expired token and calls refresh independently
function DashboardScreen() {
  // All three hooks fire on mount. If the token is expired, all three
  // trigger supabase.auth.refreshSession() concurrently
  const { data: profile } = useQuery({ queryKey: ['profile'], queryFn: fetchProfile });
  const { data: orders } = useQuery({ queryKey: ['orders'], queryFn: fetchOrders });
  const { data: notifications } = useQuery({ queryKey: ['notifications'], queryFn: fetchNotifications });

  return <View>...</View>;
}

// BAD: No error recovery on auth state changes
// When TOKEN_REFRESHED fires but the new token fails to persist,
// the next app launch has no valid session
useEffect(() => {
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN') setUser(session?.user ?? null);
    // WRONG: No handling for TOKEN_REFRESHED or SIGNED_OUT
    // No error handling if session is null unexpectedly
  });
}, []);
```

```dart
// BAD (Flutter): Manually refreshing tokens without coordination
// Multiple widgets call refreshSession simultaneously
class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    // WRONG: If token is expired, this triggers a refresh
    _loadProfile();
    _loadOrders(); // This also tries to refresh the same expired token
    _loadNotifications(); // And this one too - race condition
  }

  Future<void> _loadProfile() async {
    // Supabase client internally detects expired token and refreshes
    // But three concurrent calls = three refresh attempts
    final response = await supabase.from('profiles').select().single();
  }
}
```

## Solution

### React Native: Supabase Client with Proper Session Handling

```typescript
// GOOD: Supabase client configured to prevent race conditions
// src/lib/supabase.ts
import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppState, Platform } from 'react-native';

export const supabase = createClient(
  process.env.EXPO_PUBLIC_SUPABASE_URL!,
  process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!,
  {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,  // Supabase JS handles refresh internally
      persistSession: true,
      detectSessionInUrl: false, // Required for RN - no browser URL bar
      flowType: 'pkce', // PKCE is required for mobile - no client secret
      // Lock prevents concurrent refresh attempts
      lock: 'navigator' in globalThis ? undefined : createLock(),
    },
  }
);

// Handle app state changes - refresh token when coming to foreground
// This prevents stale tokens after long background periods
AppState.addEventListener('change', (state) => {
  if (state === 'active') {
    supabase.auth.startAutoRefresh();
  } else {
    supabase.auth.stopAutoRefresh();
  }
});
```

### React Native: Auth State Management

```typescript
// GOOD: Centralized auth state with comprehensive event handling
// src/providers/AuthProvider.tsx
import { Session, AuthChangeEvent } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

type AuthState = {
  session: Session | null;
  isLoading: boolean;
  isInitialized: boolean;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({
    session: null,
    isLoading: true,
    isInitialized: false,
  });

  useEffect(() => {
    // 1. Get initial session from storage
    supabase.auth.getSession().then(({ data: { session }, error }) => {
      if (error) {
        console.error('Failed to restore session:', error.message);
        // Session is corrupted - clear it and start fresh
        supabase.auth.signOut();
      }
      setState({ session, isLoading: false, isInitialized: true });
    });

    // 2. Listen for all auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event: AuthChangeEvent, session: Session | null) => {
        switch (event) {
          case 'SIGNED_IN':
          case 'TOKEN_REFRESHED':
            setState((prev) => ({ ...prev, session, isLoading: false }));
            break;

          case 'SIGNED_OUT':
            setState({ session: null, isLoading: false, isInitialized: true });
            // Clear all cached data on signout
            queryClient.clear();
            break;

          case 'USER_UPDATED':
            setState((prev) => ({ ...prev, session }));
            // Invalidate profile queries to reflect updated user data
            queryClient.invalidateQueries({ queryKey: ['profile'] });
            break;

          case 'PASSWORD_RECOVERY':
            // Navigate to password reset screen
            break;
        }
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  return (
    <AuthContext.Provider value={state}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
```

### React Native: Social Auth (Google + Apple)

```typescript
// GOOD: Google Sign-In with Supabase using ID token flow
// src/auth/googleAuth.ts
import {
  GoogleSignin,
  statusCodes,
} from '@react-native-google-signin/google-signin';

GoogleSignin.configure({
  // Web client ID from Google Cloud Console (NOT iOS or Android client ID)
  webClientId: process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
  offlineAccess: true,
});

export async function signInWithGoogle() {
  try {
    await GoogleSignin.hasPlayServices();
    const userInfo = await GoogleSignin.signIn();
    const idToken = userInfo.data?.idToken;

    if (!idToken) throw new Error('No ID token from Google');

    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
    });

    if (error) throw error;
    return data;
  } catch (error: any) {
    if (error.code === statusCodes.SIGN_IN_CANCELLED) {
      return null; // User cancelled - not an error
    }
    if (error.code === statusCodes.IN_PROGRESS) {
      return null; // Sign-in already in progress
    }
    throw error;
  }
}

// GOOD: Apple Sign-In with Supabase
// src/auth/appleAuth.ts
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Crypto from 'expo-crypto';

export async function signInWithApple() {
  // Generate nonce for security - prevents replay attacks
  const rawNonce = Crypto.getRandomBytes(32)
    .reduce((acc, byte) => acc + byte.toString(16).padStart(2, '0'), '');
  const hashedNonce = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    rawNonce
  );

  try {
    const credential = await AppleAuthentication.signInAsync({
      requestedScopes: [
        AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
        AppleAuthentication.AppleAuthenticationScope.EMAIL,
      ],
      nonce: hashedNonce,
    });

    if (!credential.identityToken) {
      throw new Error('No identity token from Apple');
    }

    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'apple',
      token: credential.identityToken,
      nonce: rawNonce, // Send the RAW nonce, not the hashed one
    });

    if (error) throw error;

    // Apple only provides name on first sign-in
    // Store it in user metadata if available
    if (credential.fullName?.givenName) {
      await supabase.auth.updateUser({
        data: {
          full_name: `${credential.fullName.givenName} ${credential.fullName.familyName ?? ''}`.trim(),
        },
      });
    }

    return data;
  } catch (error: any) {
    if (error.code === 'ERR_REQUEST_CANCELED') return null;
    throw error;
  }
}
```

### Flutter: Supabase Client Setup with PKCE

```dart
// GOOD: Flutter Supabase initialization with proper auth configuration
// lib/main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // PKCE for mobile security
      autoRefreshToken: true,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;
```

### Flutter: Auth State with Riverpod

```dart
// GOOD: Auth state provider that handles all edge cases
// lib/features/auth/providers/auth_provider.dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  StreamSubscription<AuthState>? _subscription;

  @override
  AsyncValue<Session?> build() {
    // Get current session synchronously
    final currentSession = supabase.auth.currentSession;

    // Listen for auth state changes
    _subscription?.cancel();
    _subscription = supabase.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
          state = AsyncData(data.session);
          break;

        case AuthChangeEvent.signedOut:
          state = const AsyncData(null);
          // Clear all cached providers
          ref.invalidate(profileProvider);
          ref.invalidate(ordersProvider);
          break;

        case AuthChangeEvent.userUpdated:
          state = AsyncData(data.session);
          ref.invalidate(profileProvider);
          break;

        default:
          break;
      }
    });

    ref.onDispose(() => _subscription?.cancel());

    return AsyncData(currentSession);
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = AsyncData(response.session);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      state = const AsyncData(null);
    } catch (e) {
      // Even if signOut API fails, clear local session
      state = const AsyncData(null);
    }
  }
}

// Derived provider: is the user authenticated?
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  return ref.watch(authProvider).valueOrNull != null;
}
```

### Flutter: Social Auth (Google + Apple)

```dart
// GOOD: Google Sign-In for Flutter with Supabase
// lib/features/auth/services/social_auth.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class SocialAuthService {
  final SupabaseClient _supabase;

  SocialAuthService(this._supabase);

  Future<AuthResponse> signInWithGoogle() async {
    // Web client ID must match what is configured in Supabase dashboard
    final googleSignIn = GoogleSignIn(
      serverClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw AuthException('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw AuthException('No ID token from Google');

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    // Generate nonce for PKCE security
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) throw AuthException('No identity token from Apple');

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce, // Raw nonce, NOT hashed
    );

    // Apple provides name only on first sign-in
    if (credential.givenName != null) {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name':
                '${credential.givenName} ${credential.familyName ?? ''}'.trim(),
          },
        ),
      );
    }

    return response;
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
```

## Why This Works

- **Supabase JS client v2 has built-in refresh locking**: The `autoRefreshToken: true` setting uses an internal lock to serialize refresh attempts. When multiple API calls detect an expired token, only one refresh executes. The others wait for the result. This eliminates the race condition.
- **PKCE flow eliminates client secret exposure**: Mobile apps cannot securely store client secrets (they can be extracted from the binary). PKCE uses a dynamically generated code verifier/challenge pair instead. The verifier never leaves the device.
- **`onAuthStateChange` covers all token lifecycle events**: Listening for `TOKEN_REFRESHED`, `SIGNED_OUT`, and `USER_UPDATED` ensures the app always has the correct session state, including after background refresh.
- **App state listener manages refresh lifecycle**: Stopping auto-refresh when the app is backgrounded prevents wasted network requests. Restarting it on foreground ensures the token is fresh when the user returns.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Apple Sign-In is **required** by App Store Review if you offer any other social login (Google, GitHub, etc.).
- Apple only sends the user's name on the **first** sign-in. If you miss it, the user must go to Settings > Apple ID > Password & Security > Apps Using Apple ID > Your App > Stop Using Apple ID, then sign in again.
- Background app refresh on iOS can trigger `autoRefreshToken` while the app is suspended. The OS may terminate the network request mid-flight, leaving a partially rotated token. The `onAuthStateChange` handler recovers from this on next foreground.

**Android:**
- Google Sign-In requires the SHA-1 fingerprint of your signing key in the Firebase/Google Cloud Console. Debug and release keys are different. Missing this causes `DEVELOPER_ERROR`.
- On Android 12+, the system may kill background apps aggressively. The Supabase session persisted in SharedPreferences survives this, but in-memory state does not. Always restore from `getSession()` on app start.
- Deep links for OAuth callbacks require intent filters in `AndroidManifest.xml` matching your Supabase project's redirect URL.

### Common Mistakes

- **Using `flowType: 'implicit'` on mobile**: Implicit flow returns tokens in URL fragments, which are insecure on mobile (other apps can intercept them). Always use `pkce`.
- **Sending the hashed nonce to Supabase for Apple Sign-In**: Apple receives the hashed nonce. Supabase expects the raw nonce so it can hash it itself and compare. Swapping them causes `invalid_nonce` errors.
- **Not handling `SIGNED_OUT` from server-side session revocation**: An admin can revoke sessions from the Supabase dashboard. The next `autoRefreshToken` attempt will fail, triggering `SIGNED_OUT`. If your app does not handle this event, the user sees API errors instead of being redirected to login.
- **Calling `getSession()` instead of `getUser()` for auth checks**: `getSession()` reads from local storage and may return an expired session. `getUser()` validates the token with the server. Use `getSession()` for quick local checks, `getUser()` when security matters.
- **Forgetting to configure redirect URLs in Supabase dashboard**: OAuth providers redirect back to your app after authentication. The redirect URL must be allowlisted in Supabase Dashboard > Authentication > URL Configuration. Missing this causes `redirect_uri_mismatch`.

## Verification

```bash
# Test token refresh manually (React Native)
# In your Supabase dashboard, set JWT expiry to 60 seconds for testing
# Dashboard > Authentication > Settings > JWT Expiry

# Verify PKCE flow in network inspector
# Look for 'code_verifier' in the token exchange request
# It should be present (PKCE) not absent (implicit)

# Test Apple Sign-In on simulator
# Requires Xcode > Signing & Capabilities > Sign In with Apple
```

- [ ] Sign in, wait for token expiry (set to 60s for testing). Make an API call. Verify auto-refresh happens without logout.
- [ ] Sign in, kill app, wait 2 hours, reopen. Verify session is restored and token is refreshed.
- [ ] Open 3 screens simultaneously that all fetch data. Verify only 1 token refresh request appears in network logs.
- [ ] Sign in with Google on iOS and Android. Verify both platforms receive valid sessions.
- [ ] Sign in with Apple. Verify user name is captured and stored in metadata.
- [ ] Revoke session from Supabase dashboard. Verify app detects `SIGNED_OUT` and navigates to login.
- [ ] Go offline, wait for token expiry, come back online. Verify session recovers.

## References

- [Supabase Auth - React Native](https://supabase.com/docs/guides/auth/quickstarts/react-native)
- [Supabase Auth - Flutter](https://supabase.com/docs/guides/auth/quickstarts/flutter)
- [Supabase Auth - Social Login](https://supabase.com/docs/guides/auth/social-login)
- [Supabase Auth - PKCE Flow](https://supabase.com/docs/guides/auth/sessions/pkce-flow)
- [Apple Sign In with Supabase](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Google Sign In with Supabase](https://supabase.com/docs/guides/auth/social-login/auth-google)
