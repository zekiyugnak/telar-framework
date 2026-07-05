# Mobile Security Audit Checklist

Based on OWASP Mobile Top 10 (2024) with mobile-specific mitigations.

## M1: Improper Credential Usage

- [ ] No hardcoded API keys, secrets, or tokens in source code
- [ ] Secrets stored in environment variables or secure vaults
- [ ] API keys rotated regularly
- [ ] Service role keys never used in client-side code
- [ ] `.env` files in `.gitignore`
- [ ] CI/CD secrets use encrypted storage (GitHub Secrets, etc.)

## M2: Inadequate Supply Chain Security

- [ ] Dependencies audited (`npm audit`, `flutter pub outdated`)
- [ ] Lock files committed (package-lock.json, pubspec.lock)
- [ ] No known vulnerable dependencies
- [ ] Third-party SDKs reviewed for data collection
- [ ] Native module sources verified

## M3: Insecure Authentication/Authorization

- [ ] Authentication tokens stored in Keychain/Keystore (not AsyncStorage)
- [ ] Token refresh handled with proper locking (no race conditions)
- [ ] Session timeout implemented
- [ ] Biometric authentication for sensitive operations
- [ ] Server-side session validation on every request
- [ ] Logout clears all local credentials and tokens
- [ ] No client-side-only authorization checks

## M4: Insufficient Input/Output Validation

- [ ] All user input validated before use
- [ ] SQL injection prevented (parameterized queries, RLS)
- [ ] XSS prevented in WebView content
- [ ] Deep link parameters validated and sanitized
- [ ] File upload types and sizes restricted
- [ ] Server responses validated before rendering

## M5: Insecure Communication

- [ ] All network traffic over HTTPS
- [ ] Certificate pinning implemented for critical APIs
- [ ] No HTTP exceptions in network security config (production)
- [ ] TLS 1.2+ enforced
- [ ] WebSocket connections use WSS
- [ ] No sensitive data in URL parameters

## M6: Inadequate Privacy Controls

- [ ] Minimum necessary data collected
- [ ] User consent obtained before data collection
- [ ] Data retention policies implemented
- [ ] Account deletion removes all user data
- [ ] Analytics anonymized where possible
- [ ] Camera/microphone permissions requested only when needed
- [ ] Location precision appropriate for use case

## M7: Insufficient Binary Protections

- [ ] Code obfuscation enabled (ProGuard/R8 for Android)
- [ ] Debug mode disabled in production builds
- [ ] Root/jailbreak detection for sensitive apps
- [ ] Anti-tampering checks for financial apps
- [ ] Source maps not included in production bundles
- [ ] Hermes bytecode used (harder to reverse than JS)

## M8: Security Misconfiguration

- [ ] Debug logging disabled in production
- [ ] Sensitive data not logged (tokens, passwords, PII)
- [ ] Backup configuration reviewed (android:allowBackup)
- [ ] Exported components intentionally public only
- [ ] Content providers properly secured
- [ ] iOS ATS (App Transport Security) not disabled globally
- [ ] WebView JavaScript interface restricted

## M9: Insecure Data Storage

- [ ] Sensitive data encrypted at rest
- [ ] Keychain/Keystore used for credentials
- [ ] Database encryption for local databases (SQLCipher)
- [ ] Clipboard cleared after sensitive operations
- [ ] Screenshot prevention for sensitive screens
- [ ] Cache cleared on logout
- [ ] Temporary files cleaned up

## M10: Insufficient Cryptography

- [ ] Strong encryption algorithms (AES-256, RSA-2048+)
- [ ] No custom cryptography implementations
- [ ] Encryption keys not hardcoded
- [ ] Keys stored in hardware-backed keystore when available
- [ ] Proper random number generation (SecureRandom)
- [ ] Hash functions use bcrypt/scrypt/argon2 for passwords

## Additional Mobile Checks

### React Native Specific
- [ ] Hermes enabled (bytecode harder to reverse than JS)
- [ ] Metro bundler tree-shaking removing unused code
- [ ] No sensitive data in JS thread console logs
- [ ] Native module permissions properly scoped

### Flutter Specific
- [ ] `--obfuscate` and `--split-debug-info` used for release builds
- [ ] Platform channels don't expose sensitive data
- [ ] Dart runtime not leaking stack traces in production

### Supabase Specific
- [ ] RLS enabled on all tables
- [ ] RLS policies tested (not just trusted)
- [ ] Anon key has minimal permissions
- [ ] Service role key never in client code
- [ ] Edge Functions validate JWT tokens
