---
id: biometric-auth
category: skill
tags: [biometric, face-id, touch-id, fingerprint, authentication]
capabilities:
  - Face ID/Touch ID implementation
  - Fingerprint authentication
  - Fallback strategies
  - Biometric enrollment detection
useWhen:
  - Adding biometric login
  - Securing sensitive operations
  - Implementing quick unlock
---

# Biometric Authentication

Implementing Face ID, Touch ID, and fingerprint authentication.

## React Native

```typescript
import * as LocalAuthentication from 'expo-local-authentication'

async function checkBiometricSupport() {
  const hasHardware = await LocalAuthentication.hasHardwareAsync()
  const isEnrolled = await LocalAuthentication.isEnrolledAsync()
  const types = await LocalAuthentication.supportedAuthenticationTypesAsync()

  return { hasHardware, isEnrolled, types }
}

async function authenticate() {
  const result = await LocalAuthentication.authenticateAsync({
    promptMessage: 'Authenticate to continue',
    fallbackLabel: 'Use passcode',
    cancelLabel: 'Cancel',
    disableDeviceFallback: false,
  })

  if (result.success) {
    // Authentication succeeded
    return true
  }

  if (result.error === 'user_cancel') {
    // User cancelled
  }

  return false
}
```

## Flutter

```dart
import 'package:local_auth/local_auth.dart';

final LocalAuthentication auth = LocalAuthentication();

Future<bool> authenticate() async {
  final canAuthenticate = await auth.canCheckBiometrics ||
      await auth.isDeviceSupported();

  if (!canAuthenticate) return false;

  try {
    return await auth.authenticate(
      localizedReason: 'Authenticate to access your account',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
  } on PlatformException {
    return false;
  }
}
```

## Secure Storage Integration

```typescript
// Store token with biometric protection
await Keychain.setGenericPassword('biometric', token, {
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_ANY,
})

// Retrieve (prompts biometric)
const creds = await Keychain.getGenericPassword({
  authenticationPrompt: { title: 'Unlock with biometrics' },
})
```

## Best Practices

- Check for biometric enrollment before offering
- Always provide fallback (passcode)
- Don't rely solely on biometrics for security
- Handle graceful degradation
