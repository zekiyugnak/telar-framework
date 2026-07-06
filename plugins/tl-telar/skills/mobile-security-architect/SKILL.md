---
name: "mobile-security-architect"
description: "Principal engineer specializing in mobile application security and compliance."
source_type: "agent"
source_file: "agents/mobile-security-architect.md"
---

# mobile-security-architect

Migrated from `agents/mobile-security-architect.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Security Architect

Principal engineer specializing in mobile application security and compliance.

## OWASP Mobile Top 10

**Key Vulnerabilities to Address:**
```markdown
M1: Improper Platform Usage
- Use platform security features correctly
- Validate all user inputs
- Follow iOS/Android security best practices

M2: Insecure Data Storage
- Never store sensitive data in plain text
- Use Keychain (iOS) / Keystore (Android)
- Encrypt local databases

M3: Insecure Communication
- Use TLS 1.2+ for all connections
- Implement certificate pinning
- Never transmit sensitive data over HTTP

M4: Insecure Authentication
- Implement proper session management
- Use secure token storage
- Support biometric authentication

M5: Insufficient Cryptography
- Use platform-provided crypto APIs
- Never implement custom crypto
- Use strong, modern algorithms (AES-256, RSA-2048+)

M6: Insecure Authorization
- Validate authorization server-side
- Implement proper access controls
- Never trust client-side only checks

M7: Client Code Quality
- Sanitize all inputs
- Use static analysis tools
- Regular security code reviews

M8: Code Tampering
- Implement integrity checks
- Use code obfuscation
- Detect jailbreak/root

M9: Reverse Engineering
- Obfuscate sensitive code
- Never hardcode secrets
- Use runtime protection

M10: Extraneous Functionality
- Remove debug code in production
- Disable verbose logging
- Remove test backdoors
```

## Secure API Design

```typescript
// Rate limiting
const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // requests per window
  keyGenerator: (req) => req.user?.id || req.ip,
  handler: (req, res) => {
    res.status(429).json({ error: 'Too many requests' })
  },
})

// Input validation
import { z } from 'zod'

const createUserSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(255).regex(/^[a-zA-Z\s'-]+$/),
})

// SQL injection prevention (use parameterized queries)
// NEVER: `SELECT * FROM users WHERE id = '${userId}'`
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId])

// XSS prevention
import DOMPurify from 'dompurify'
const sanitizedContent = DOMPurify.sanitize(userInput)

// CSRF protection
app.use(csrf({ cookie: true }))
```

## Data Encryption

**At Rest:**
```typescript
// Encrypt sensitive fields before storage
import crypto from 'crypto'

class EncryptionService {
  private algorithm = 'aes-256-gcm'
  private key: Buffer

  constructor(keyBase64: string) {
    this.key = Buffer.from(keyBase64, 'base64')
  }

  encrypt(plaintext: string): EncryptedData {
    const iv = crypto.randomBytes(16)
    const cipher = crypto.createCipheriv(this.algorithm, this.key, iv)

    let encrypted = cipher.update(plaintext, 'utf8', 'base64')
    encrypted += cipher.final('base64')

    return {
      ciphertext: encrypted,
      iv: iv.toString('base64'),
      authTag: cipher.getAuthTag().toString('base64'),
    }
  }

  decrypt(data: EncryptedData): string {
    const decipher = crypto.createDecipheriv(
      this.algorithm,
      this.key,
      Buffer.from(data.iv, 'base64')
    )
    decipher.setAuthTag(Buffer.from(data.authTag, 'base64'))

    let decrypted = decipher.update(data.ciphertext, 'base64', 'utf8')
    decrypted += decipher.final('utf8')

    return decrypted
  }
}

// Usage for PII
const encryptedSSN = encryptionService.encrypt(ssn)
await db.users.update(userId, { ssn_encrypted: encryptedSSN })
```

**In Transit:**
```typescript
// Certificate pinning (React Native)
import { fetch } from 'react-native-ssl-pinning'

const secureFetch = (url: string, options: RequestInit) => {
  return fetch(url, {
    ...options,
    sslPinning: {
      certs: ['api_cert'], // Certificate in assets
    },
  })
}

// Or with public key pinning
const PUBLIC_KEY_HASHES = [
  'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup
]
```

## GDPR Compliance

```typescript
// Data export (Right to Access)
async function exportUserData(userId: string): Promise<UserDataExport> {
  const user = await db.users.findById(userId)
  const tasks = await db.tasks.findByUser(userId)
  const activities = await db.activityLog.findByUser(userId)

  return {
    user: {
      email: user.email,
      name: user.name,
      createdAt: user.createdAt,
    },
    tasks: tasks.map(t => ({
      title: t.title,
      createdAt: t.createdAt,
    })),
    activities: activities.map(a => ({
      action: a.action,
      timestamp: a.timestamp,
    })),
    exportedAt: new Date().toISOString(),
  }
}

// Data deletion (Right to Erasure)
async function deleteUserData(userId: string): Promise<void> {
  await db.transaction(async (tx) => {
    // Delete user's content
    await tx.tasks.deleteMany({ createdBy: userId })
    await tx.comments.deleteMany({ userId })

    // Anonymize activity logs (keep for analytics)
    await tx.activityLog.updateMany(
      { userId },
      { userId: 'deleted', ip: null }
    )

    // Delete PII
    await tx.pushTokens.deleteMany({ userId })
    await tx.refreshTokens.deleteMany({ userId })
    await tx.users.delete(userId)
  })

  // Schedule storage cleanup
  await queue.add('cleanup-user-files', { userId })
}

// Consent management
interface ConsentRecord {
  userId: string
  type: 'marketing' | 'analytics' | 'necessary'
  granted: boolean
  timestamp: Date
  ipAddress: string
}

async function recordConsent(userId: string, consents: Consent[]): Promise<void> {
  const records = consents.map(c => ({
    userId,
    type: c.type,
    granted: c.granted,
    timestamp: new Date(),
    ipAddress: request.ip,
  }))

  await db.consentRecords.insertMany(records)
}
```

## Threat Modeling

```markdown
## Mobile App Threat Model

### Assets
- User credentials (email, password hash)
- Authentication tokens
- Personal data (name, email, preferences)
- User-generated content

### Threat Actors
1. Malicious users (account takeover)
2. Network attackers (MITM)
3. Malware on device
4. Curious users (reverse engineering)

### Attack Vectors
1. Credential stuffing → Mitigate: Rate limiting, MFA
2. Token theft → Mitigate: Secure storage, short expiry
3. Network interception → Mitigate: TLS, cert pinning
4. Local data theft → Mitigate: Encryption, secure storage
5. API abuse → Mitigate: Input validation, authorization

### Security Controls
- Authentication: OAuth 2.0 + PKCE, MFA optional
- Authorization: Role-based, server-side validation
- Data protection: AES-256 encryption, TLS 1.3
- Monitoring: Anomaly detection, audit logging
```

## Security Checklist

```markdown
Pre-Release Security Checklist:

Authentication:
- [ ] Passwords hashed with bcrypt/Argon2
- [ ] JWT tokens short-lived (15 min)
- [ ] Refresh token rotation implemented
- [ ] Failed login rate limiting

Data Protection:
- [ ] PII encrypted at rest
- [ ] TLS 1.2+ for all connections
- [ ] Certificate pinning enabled
- [ ] Secure storage for tokens (Keychain/Keystore)

API Security:
- [ ] Input validation on all endpoints
- [ ] Parameterized queries (no SQL injection)
- [ ] Rate limiting implemented
- [ ] CORS properly configured

Mobile Security:
- [ ] No sensitive data in logs
- [ ] No hardcoded secrets
- [ ] Jailbreak/root detection
- [ ] Code obfuscation (release builds)
```

## Best Practices

- **Defense in depth** - multiple security layers
- **Principle of least privilege** - minimal permissions
- **Fail securely** - errors don't expose sensitive data
- **Keep dependencies updated** - security patches
- **Regular security audits** - third-party pen testing

## Common Pitfalls

- Storing sensitive data in plain text
- Trusting client-side validation alone
- Exposing stack traces in production
- Insufficient logging for security events
