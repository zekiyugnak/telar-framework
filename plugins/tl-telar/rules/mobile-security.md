# Mobile Security Standards

## Data Protection

### Secure Storage
| Data Type | iOS | Android |
|-----------|-----|---------|
| Credentials | Keychain | EncryptedSharedPreferences / Keystore |
| Tokens | Keychain | EncryptedSharedPreferences |
| User Data | Encrypted CoreData | Encrypted Room/SQLite |
| Files | Data Protection API | Encrypted File Storage |

### Encryption Requirements
- AES-256 for data at rest
- TLS 1.3 for data in transit
- Certificate pinning for API endpoints
- No sensitive data in logs or crash reports

## Authentication

### Mandatory Practices
1. **Token Management**
   - Short-lived access tokens (15-60 min)
   - Secure refresh token storage
   - Token rotation on security events

2. **Biometric Authentication**
   - Use platform APIs (LocalAuthentication / BiometricPrompt)
   - Fallback to secure PIN
   - Handle biometric changes

3. **Session Security**
   - Automatic logout on inactivity
   - Session invalidation on password change
   - Device binding for sensitive apps

## Network Security

### API Communication
- [ ] HTTPS only (no HTTP fallback)
- [ ] Certificate pinning implemented
- [ ] Request signing for critical endpoints
- [ ] Rate limiting awareness

### Certificate Pinning
```dart
// Flutter example
final client = HttpClient()
  ..badCertificateCallback = (cert, host, port) {
    return pinnedCerts.contains(cert.sha256);
  };
```

```typescript
// React Native example (react-native-ssl-pinning)
fetch(url, {
  sslPinning: {
    certs: ['cert1', 'cert2']
  }
});
```

## Code Security

### Obfuscation
- Enable ProGuard/R8 for Android release builds
- Enable Bitcode for iOS
- Remove debug symbols in release

### Anti-Tampering
- Integrity checks for critical code
- Jailbreak/root detection (when appropriate)
- Debugger detection for high-security apps

## OWASP Mobile Top 10 Checklist

1. **M1: Improper Platform Usage** - Use platform security features correctly
2. **M2: Insecure Data Storage** - Encrypt sensitive data at rest
3. **M3: Insecure Communication** - TLS + certificate pinning
4. **M4: Insecure Authentication** - Strong auth + session management
5. **M5: Insufficient Cryptography** - Use proven algorithms (AES, RSA)
6. **M6: Insecure Authorization** - Server-side authorization checks
7. **M7: Client Code Quality** - Input validation, buffer overflow prevention
8. **M8: Code Tampering** - Integrity verification
9. **M9: Reverse Engineering** - Obfuscation, anti-tampering
10. **M10: Extraneous Functionality** - Remove test code, disable logging
