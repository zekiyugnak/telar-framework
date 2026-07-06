---
name: "blueprint-auth-flow"
description: "Complete login/signup/forgot-password/social-auth flow with Supabase backend integration."
source_type: "blueprint"
source_file: "skills/blueprints/auth-flow.md"
---

# blueprint-auth-flow

Migrated from `skills/blueprints/auth-flow.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Blueprint: Authentication Flow

Complete login/signup/forgot-password/social-auth flow with Supabase backend integration.

## File Manifest

```markdown
# React Native (TypeScript)
src/
  screens/auth/
    LoginScreen.tsx
    SignupScreen.tsx
    ForgotPasswordScreen.tsx
    ResetPasswordScreen.tsx
    VerifyEmailScreen.tsx
  hooks/
    useAuth.ts
    useSocialAuth.ts
    useBiometricAuth.ts
  services/
    auth.ts
    secureStorage.ts
  navigation/
    AuthNavigator.tsx
  __tests__/
    useAuth.test.ts
    LoginScreen.test.tsx

# Flutter (Dart)
lib/
  features/auth/
    screens/
      login_screen.dart
      signup_screen.dart
      forgot_password_screen.dart
      reset_password_screen.dart
      verify_email_screen.dart
    providers/
      auth_provider.dart
      social_auth_provider.dart
    services/
      auth_service.dart
      secure_storage_service.dart
    widgets/
      social_auth_buttons.dart
      auth_form_field.dart
  routing/
    auth_routes.dart
test/
  features/auth/
    auth_provider_test.dart
    login_screen_test.dart
```

## React Native Implementation

### Auth Hook
```typescript
// src/hooks/useAuth.ts
import { useState, useCallback } from 'react';
import { supabase } from '../services/supabase';
import * as SecureStore from 'expo-secure-store';

interface AuthState {
  user: User | null;
  loading: boolean;
  error: string | null;
}

export function useAuth() {
  const [state, setState] = useState<AuthState>({
    user: null,
    loading: false,
    error: null,
  });

  const signIn = useCallback(async (email: string, password: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (error) throw error;
      await SecureStore.setItemAsync('session', JSON.stringify(data.session));
      setState({ user: data.user, loading: false, error: null });
    } catch (err) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : 'Sign in failed',
      }));
    }
  }, []);

  const signUp = useCallback(async (email: string, password: string, metadata?: Record<string, string>) => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    try {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: metadata },
      });
      if (error) throw error;
      setState({ user: data.user, loading: false, error: null });
    } catch (err) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : 'Sign up failed',
      }));
    }
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    await SecureStore.deleteItemAsync('session');
    setState({ user: null, loading: false, error: null });
  }, []);

  const resetPassword = useCallback(async (email: string) => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email);
      if (error) throw error;
      setState(prev => ({ ...prev, loading: false }));
    } catch (err) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: err instanceof Error ? err.message : 'Reset failed',
      }));
    }
  }, []);

  return { ...state, signIn, signUp, signOut, resetPassword };
}
```

### Login Screen
```tsx
// src/screens/auth/LoginScreen.tsx
import { View, Text, TextInput, Pressable, ActivityIndicator } from 'react-native';
import { useAuth } from '../../hooks/useAuth';
import { useSocialAuth } from '../../hooks/useSocialAuth';
import { SocialAuthButtons } from '../../components/SocialAuthButtons';

export function LoginScreen({ navigation }: LoginScreenProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { signIn, loading, error } = useAuth();

  const handleLogin = () => signIn(email, password);

  return (
    <View style={styles.container} accessibilityRole="form">
      <Text style={styles.title} accessibilityRole="header">
        Welcome Back
      </Text>

      {error && (
        <Text style={styles.error} accessibilityRole="alert">
          {error}
        </Text>
      )}

      <TextInput
        style={styles.input}
        placeholder="Email"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        autoComplete="email"
        accessibilityLabel="Email address"
        textContentType="emailAddress"
      />

      <TextInput
        style={styles.input}
        placeholder="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        autoComplete="password"
        accessibilityLabel="Password"
        textContentType="password"
      />

      <Pressable
        style={[styles.button, loading && styles.buttonDisabled]}
        onPress={handleLogin}
        disabled={loading}
        accessibilityRole="button"
        accessibilityLabel={loading ? 'Signing in' : 'Sign in'}
        accessibilityState={{ disabled: loading }}
      >
        {loading ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>Sign In</Text>
        )}
      </Pressable>

      <SocialAuthButtons />

      <Pressable
        onPress={() => navigation.navigate('ForgotPassword')}
        accessibilityRole="link"
      >
        <Text style={styles.link}>Forgot password?</Text>
      </Pressable>

      <Pressable
        onPress={() => navigation.navigate('Signup')}
        accessibilityRole="link"
      >
        <Text style={styles.link}>Don't have an account? Sign up</Text>
      </Pressable>
    </View>
  );
}
```

## Flutter Implementation

### Auth Provider
```dart
// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(Supabase.instance.client, const FlutterSecureStorage());
});

class AuthState {
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  AuthState copyWith({User? user, bool? loading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._client, this._storage) : super(const AuthState());

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _storage.write(
        key: 'session',
        value: response.session?.toJson().toString(),
      );
      state = AuthState(user: response.user);
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> signUp(String email, String password, {Map<String, String>? metadata}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      state = AuthState(user: response.user);
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await _storage.delete(key: 'session');
    state = const AuthState();
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _client.auth.resetPasswordForEmail(email);
      state = state.copyWith(loading: false);
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }
}
```

### Login Screen
```dart
// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineLarge,
                  semanticsLabel: 'Welcome Back',
                ),
                const SizedBox(height: 32),
                if (auth.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(auth.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: (v) => v != null && v.length >= 8 ? null : 'Min 8 characters',
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.loading ? null : _handleLogin,
                  child: auth.loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 16),
                const SocialAuthButtons(),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      ref.read(authProvider.notifier).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

## Supabase Backend Setup

```sql
-- Enable email auth (default)
-- Configure in Supabase Dashboard > Authentication > Providers

-- User profile table (extends auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'display_name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);
```

## Tests

```typescript
// __tests__/useAuth.test.ts
import { renderHook, act } from '@testing-library/react-hooks';
import { useAuth } from '../src/hooks/useAuth';

jest.mock('../src/services/supabase');

describe('useAuth', () => {
  it('signs in successfully', async () => {
    const { result } = renderHook(() => useAuth());

    await act(async () => {
      await result.current.signIn('test@example.com', 'password123');
    });

    expect(result.current.user).toBeTruthy();
    expect(result.current.error).toBeNull();
  });

  it('handles sign in error', async () => {
    const { result } = renderHook(() => useAuth());

    await act(async () => {
      await result.current.signIn('bad@email.com', 'wrong');
    });

    expect(result.current.user).toBeNull();
    expect(result.current.error).toBeTruthy();
  });

  it('signs out and clears session', async () => {
    const { result } = renderHook(() => useAuth());

    await act(async () => {
      await result.current.signIn('test@example.com', 'password123');
      await result.current.signOut();
    });

    expect(result.current.user).toBeNull();
  });
});
```

## Accessibility Checklist

- [x] All form fields have labels and appropriate keyboard types
- [x] Error messages announced via `accessibilityRole="alert"` / `liveRegion`
- [x] Loading state communicated to screen readers
- [x] Touch targets meet 44x44 minimum (buttons are full-width)
- [x] Password field uses `secureTextEntry` / `obscureText`
- [x] Social auth buttons have descriptive labels
- [x] Navigation between screens announced
