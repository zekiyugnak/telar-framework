---
name: "biometric-auth"
description: "Implementing Face ID, Touch ID, and fingerprint authentication."
source_type: "skill"
source_file: "skills/biometric-auth.md"
---

# biometric-auth

Migrated from `skills/biometric-auth.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
