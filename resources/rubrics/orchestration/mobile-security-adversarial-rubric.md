# Mobile Security Adversarial Rubric

## Purpose

Used by the always-on Adversarial Mobile Security Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with mobile-specific security failure modes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### S. Mobile security failures

A WU FAILS mobile security review if any of:

- S1. Sensitive data (auth tokens, PII, keys) is stored in `AsyncStorage`/`SharedPreferences`/`NSUserDefaults` without being marked for the platform keychain/Keystore. Use `react-native-keychain`, `flutter_secure_storage`, or platform equivalents.
- S2. HTTP fetch calls (not HTTPS), or `NSAllowsArbitraryLoads`/cleartext-traffic exceptions, are introduced without a documented justification.
- S3. Certificate pinning is bypassed or disabled in production builds. Debug/dev pinning relaxation is fine if guarded by build flag.
- S4. Biometric prompts (FaceID/TouchID/BiometricPrompt) are gated only by client-side flags — server validation must follow for any session token issued via biometric.
- S5. Deeplink/Universal-link handlers parse URL params and pass to internal navigation without input validation. Especially: any `eval`, dynamic require, or component name resolved from URL.
- S6. WebView introduced with `javaScriptEnabled` AND remote URLs loaded without origin whitelist OR with `allowFileAccess: true` to user-controllable paths.
- S7. Jailbreak/root detection is absent on a screen that handles payments, auth secrets, or DRM content (advisory if non-payment).
- S8. Hard-coded secrets (API keys, signing certs, OAuth secrets) appear in source or in `.env` files committed to git.
- S9. Logged messages contain PII or auth tokens (search the diff for `console.log`/`print` near auth/profile/email/phone vars).
- S10. New dependency installed has a known CVE >= 7.0 within the last 12 months (advisory; reviewer flags but does not have CVE DB access — relies on naming patterns).

## Verdict format

JSON per the schema. Use rule IDs S1-S10. The reviewer's `reviewer` field is `"mobile-security"`.
