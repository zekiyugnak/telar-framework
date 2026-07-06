---
name: "secure-storage"
description: "Auth tokens, API keys, and user credentials must be stored in platform-provided secure enclaves (iOS Keychain, Android Keystore). Storing them in AsyncStorage or SharedPreferences leaves them in plain text files readable"
source_type: "skill"
source_file: "skills/secure-storage.md"
---

# secure-storage

Migrated from `skills/secure-storage.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Secure Storage for Mobile Apps

Auth tokens, API keys, and user credentials must be stored in platform-provided secure enclaves (iOS Keychain, Android Keystore). Storing them in AsyncStorage or SharedPreferences leaves them in plain text files readable by any app on a rooted device or by a filesystem backup extraction.

## Problem

AsyncStorage on React Native and SharedPreferences on Android write plain JSON/XML files to the app's data directory. On a rooted/jailbroken device, these files are trivially readable.

```typescript
// BAD: Storing auth token in AsyncStorage - plain text on disk
import AsyncStorage from '@react-native-async-storage/async-storage';

async function login(email: string, password: string) {
  const { data } = await supabase.auth.signInWithPassword({ email, password });

  // DANGER: Token stored as plain text in:
  // Android: /data/data/com.myapp/files/AsyncStorage/token
  // iOS: Library/Application Support/RCTAsyncLocalStorage
  await AsyncStorage.setItem('access_token', data.session.access_token);
  await AsyncStorage.setItem('refresh_token', data.session.refresh_token);
}

// BAD: Reading token without any protection
async function getToken() {
  return await AsyncStorage.getItem('access_token');
  // Any app on a rooted device can read this
  // adb shell run-as com.myapp cat files/AsyncStorage/token
}
```

```dart
// BAD: Flutter SharedPreferences stores in plain XML
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  // DANGER: Written to SharedPreferences XML file, unencrypted
  // Android: /data/data/com.myapp/shared_prefs/FlutterSharedPreferences.xml
  await prefs.setString('auth_token', token);
}
```

```typescript
// BAD: Storing sensitive data without biometric protection
await AsyncStorage.setItem('credit_card', JSON.stringify(cardData));
// Anyone who picks up an unlocked phone can access this

// BAD: Using the same storage for sensitive and non-sensitive data
const storage = {
  theme: 'dark',           // Fine in AsyncStorage
  authToken: 'eyJhbG...',  // MUST be in secure storage
  lastSync: '2024-01-01',  // Fine in AsyncStorage
};
await AsyncStorage.setItem('app_data', JSON.stringify(storage));
```

## Solution

### 1. React Native: react-native-keychain

```typescript
// GOOD: Secure token storage using platform Keychain/Keystore
import * as Keychain from 'react-native-keychain';
import { Platform } from 'react-native';

// Storage service that uses hardware-backed security
class SecureTokenStorage {
  private static readonly SERVICE = 'com.myapp.auth';

  static async saveTokens(accessToken: string, refreshToken: string): Promise<void> {
    // Store in iOS Keychain / Android Keystore
    await Keychain.setGenericPassword(
      'auth_tokens', // username field (used as key)
      JSON.stringify({ accessToken, refreshToken }),
      {
        service: this.SERVICE,
        // Only accessible when device is unlocked, not in backups
        accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
        // Use hardware security module when available
        securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
        // Store type
        storage: Platform.OS === 'android'
          ? Keychain.STORAGE_TYPE.AES
          : undefined,
      }
    );
  }

  static async getTokens(): Promise<{ accessToken: string; refreshToken: string } | null> {
    try {
      const credentials = await Keychain.getGenericPassword({
        service: this.SERVICE,
      });
      if (!credentials) return null;
      return JSON.parse(credentials.password);
    } catch {
      // Keychain may throw if device security changed (e.g., passcode removed)
      return null;
    }
  }

  static async clearTokens(): Promise<void> {
    await Keychain.resetGenericPassword({ service: this.SERVICE });
  }
}
```

### 2. Biometric-Gated Access

```typescript
// GOOD: Sensitive data requires biometric authentication to read
import * as Keychain from 'react-native-keychain';
import ReactNativeBiometrics from 'react-native-biometrics';

class BiometricSecureStorage {
  static async saveWithBiometric(key: string, value: string): Promise<void> {
    await Keychain.setInternetCredentials(
      key,
      key,
      value,
      {
        // Require biometric auth (Face ID / fingerprint) to read
        accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
        // Invalidate if biometrics change (new fingerprint added)
        accessible: Keychain.ACCESSIBLE.WHEN_PASSCODE_SET_THIS_DEVICE_ONLY,
      }
    );
  }

  static async readWithBiometric(key: string): Promise<string | null> {
    try {
      // This triggers the biometric prompt automatically on iOS
      // On Android, trigger biometric first then read
      if (Platform.OS === 'android') {
        const biometrics = new ReactNativeBiometrics();
        const { success } = await biometrics.simplePrompt({
          promptMessage: 'Authenticate to access secure data',
          cancelButtonText: 'Cancel',
        });
        if (!success) return null;
      }

      const credentials = await Keychain.getInternetCredentials(key);
      if (!credentials) return null;
      return credentials.password;
    } catch (error: any) {
      if (error.message?.includes('User canceled')) {
        return null; // User dismissed biometric prompt
      }
      throw error;
    }
  }

  static async checkBiometricAvailability(): Promise<{
    available: boolean;
    biometryType: 'FaceID' | 'TouchID' | 'Biometrics' | null;
  }> {
    const biometrics = new ReactNativeBiometrics();
    const { available, biometryType } = await biometrics.isSensorAvailable();
    return { available, biometryType: available ? biometryType : null };
  }
}
```

### 3. Expo: expo-secure-store

```typescript
// GOOD: expo-secure-store for Expo managed workflow
import * as SecureStore from 'expo-secure-store';

class ExpoSecureStorage {
  static async save(key: string, value: string): Promise<void> {
    await SecureStore.setItemAsync(key, value, {
      // iOS: Keychain item not included in backups
      // Android: Uses EncryptedSharedPreferences (AES-256)
      keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      // Require device authentication
      requireAuthentication: false, // Set true for biometric gating
      authenticationPrompt: 'Authenticate to access your account',
    });
  }

  static async read(key: string): Promise<string | null> {
    return await SecureStore.getItemAsync(key, {
      keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
    });
  }

  static async remove(key: string): Promise<void> {
    await SecureStore.deleteItemAsync(key);
  }
}

// NOTE: expo-secure-store has a 2048 byte value limit
// For larger data, encrypt with a key stored in SecureStore
// and save the encrypted blob in regular storage
```

### 4. Flutter: flutter_secure_storage

```dart
// GOOD: Flutter secure storage with platform-specific options
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Use EncryptedSharedPreferences (API 23+)
      encryptedSharedPreferences: true,
      // Require device screen lock
      // keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      // storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      // Accessible only when device is unlocked
      accessibility: KeychainAccessibility.first_unlock_this_device,
      // Do not sync to iCloud Keychain
      synchronizable: false,
    ),
  );

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  static Future<String?> readToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // For data larger than a few KB, use key-wrapping pattern
  static Future<void> saveLargeSecureData(String key, String data) async {
    // Generate a random AES key
    final encryptionKey = _generateRandomKey();

    // Store the AES key in secure storage (hardware-backed)
    await _storage.write(key: '${key}_key', value: encryptionKey);

    // Encrypt data with AES key and store in regular file
    final encrypted = _aesEncrypt(data, encryptionKey);
    final file = File('${appDir.path}/$key.enc');
    await file.writeAsString(encrypted);
  }
}
```

### 5. MMKV for High-Performance Encrypted Storage

```typescript
// GOOD: MMKV provides encryption + performance for frequent access data
import { MMKV } from 'react-native-mmkv';

// MMKV is 30x faster than AsyncStorage for read/write
// It supports optional AES-128 encryption
const encryptedStorage = new MMKV({
  id: 'app-secure',
  // AES-128 CFB encryption - key should come from Keychain
  encryptionKey: 'loaded-from-keychain', // See below for proper key management
});

// Proper key management: store MMKV encryption key in Keychain
class EncryptedMMKV {
  private storage: MMKV | null = null;

  async initialize(): Promise<void> {
    // Get or create encryption key from secure hardware
    let encKey = await SecureTokenStorage.getTokens();

    if (!encKey) {
      // Generate random key on first launch
      const randomKey = Array.from(
        { length: 16 },
        () => Math.random().toString(36)[2]
      ).join('');
      await Keychain.setGenericPassword('mmkv', randomKey, {
        service: 'com.myapp.mmkv',
        accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      });
      encKey = { accessToken: randomKey, refreshToken: '' };
    }

    this.storage = new MMKV({
      id: 'app-encrypted',
      encryptionKey: encKey.accessToken,
    });
  }

  set(key: string, value: string): void {
    this.storage!.set(key, value);
  }

  get(key: string): string | undefined {
    return this.storage!.getString(key);
  }

  delete(key: string): void {
    this.storage!.delete(key);
  }
}
```

### 6. Storage Decision Matrix

```typescript
// GOOD: Use the right storage for each data type

// Tier 1: Hardware-backed secure storage (Keychain/Keystore)
// Use for: auth tokens, refresh tokens, API keys, encryption keys
// Libraries: react-native-keychain, expo-secure-store, flutter_secure_storage
// Speed: ~5-10ms per read/write
// Limit: ~few KB per item (expo-secure-store: 2048 bytes)
await Keychain.setGenericPassword('auth', token);

// Tier 2: Encrypted fast storage (MMKV with encryption)
// Use for: session data, cached credentials, encrypted user preferences
// Libraries: react-native-mmkv
// Speed: ~0.01ms per read/write (30x faster than AsyncStorage)
// Limit: No practical limit
encryptedMmkv.set('session', JSON.stringify(sessionData));

// Tier 3: Regular fast storage (MMKV without encryption, AsyncStorage)
// Use for: user preferences, theme, language, non-sensitive cache
// Libraries: react-native-mmkv, @react-native-async-storage/async-storage
// Speed: MMKV ~0.01ms, AsyncStorage ~5ms
mmkv.set('theme', 'dark');

// Tier 4: Database (SQLite, WatermelonDB)
// Use for: large datasets, queryable data, offline cache
// Libraries: expo-sqlite, react-native-sqlite-storage, watermelondb
await db.execute('INSERT INTO posts ...');

/*
 * Performance comparison (1000 sequential reads):
 * MMKV:           ~10ms   (0.01ms per read)
 * AsyncStorage:   ~5000ms (5ms per read)
 * SecureStore:    ~8000ms (8ms per read)
 * Keychain:       ~6000ms (6ms per read)
 *
 * Use Keychain for tokens (infrequent access).
 * Use MMKV for anything accessed frequently.
 * Never use Keychain/SecureStore in a hot loop.
 */
```

## Why This Works

- **iOS Keychain**: Data is encrypted by the Secure Enclave hardware co-processor. Even a full filesystem dump cannot decrypt Keychain items without the device passcode. Items marked `WHEN_UNLOCKED_THIS_DEVICE_ONLY` are not included in iTunes/Finder backups.
- **Android Keystore**: Encryption keys are generated and stored inside the Trusted Execution Environment (TEE) or StrongBox (if available). The key material never leaves the secure hardware, making extraction impractical even on rooted devices.
- **Biometric gating**: Adding `ACCESS_CONTROL.BIOMETRY_CURRENT_SET` means the Keychain item is invalidated if the user adds a new fingerprint, preventing an attacker from adding their own biometric and accessing stored data.
- **MMKV encryption**: Uses AES-128-CFB encryption on the mmap'd file. The encryption key itself is stored in Keychain, creating a two-layer protection: MMKV file is encrypted on disk, and its key is in hardware-backed storage.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Keychain items persist through app uninstall/reinstall. Call `resetGenericPassword()` on first launch if needed (check with a flag in UserDefaults).
- `WHEN_UNLOCKED` items are inaccessible when the device is locked, which breaks background refresh. Use `AFTER_FIRST_UNLOCK` for tokens needed in background.
- Keychain Sharing between apps requires the same App ID prefix and explicit entitlement.

**Android:**
- Android Keystore requires API 23+ (Android 6.0) for AES symmetric keys. Older devices fall back to software encryption.
- `EncryptedSharedPreferences` can be slow on first access (~50ms) due to key derivation. Do not call on the main thread.
- Factory reset wipes the Keystore. Users must re-authenticate after device reset.
- Some Samsung devices have Keystore bugs. Test on real Samsung hardware.

### Common Mistakes

- **Logging tokens**: Never log token values, even in debug builds. Use `token.substring(0, 8) + '...'` if debugging.
- **Storing in Redux/state without clearing**: If tokens are in Redux, ensure they are cleared from memory on logout, not just from storage.
- **expo-secure-store 2048 byte limit**: Large JWTs can exceed this. Store the token directly in Keychain via a custom native module, or compress/split.
- **Not clearing on logout**: Always clear all secure storage entries on user logout. Create a `clearAllSecureData()` function.
- **Testing only on emulators**: Emulators often lack hardware security modules. Biometric and Keystore behavior differs on real devices.

## Verification

```bash
# Android: Verify no sensitive data in SharedPreferences
adb shell run-as com.myapp ls shared_prefs/
adb shell run-as com.myapp cat shared_prefs/com.myapp_preferences.xml
# Should NOT contain any tokens or secrets

# Android: Check if Keystore is hardware-backed
adb shell getprop ro.hardware.keystore
# Should return a TEE implementation name

# iOS: Inspect Keychain (debug builds only)
# Use Xcode > Devices & Simulators > Download Container
# Check that no tokens appear in Documents/ or Library/
```

- [ ] Auth tokens stored exclusively in Keychain/Keystore (not AsyncStorage)
- [ ] `adb shell` inspection shows no tokens in SharedPreferences or app files
- [ ] Biometric prompt appears when accessing protected data
- [ ] Tokens are inaccessible when device is locked (test with `WHEN_UNLOCKED`)
- [ ] All secure storage is cleared on logout
- [ ] App handles missing Keychain entries gracefully (e.g., after iOS reinstall)
- [ ] MMKV encryption key is stored in Keychain, not hardcoded

## References

- [react-native-keychain Documentation](https://github.com/oblador/react-native-keychain)
- [expo-secure-store API](https://docs.expo.dev/versions/latest/sdk/securestore/)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)
- [react-native-mmkv](https://github.com/mrousavy/react-native-mmkv)
- [OWASP Mobile Security Testing Guide - Data Storage](https://mas.owasp.org/MASTG/tests/ios/MASVS-STORAGE/)
