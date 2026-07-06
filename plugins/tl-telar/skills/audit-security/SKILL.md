---
name: "audit-security"
description: "Comprehensive security audit for mobile applications covering OWASP mobile top 10 with P1/P2/P3 priority ranking and evidence-based findings"
source_type: "command"
source_file: "commands/audit-security.md"
---

# audit-security

Migrated from `commands/audit-security.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:audit-security`; invoke it as `$audit-security` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Security Audit

Comprehensive mobile security audit based on OWASP Mobile Top 10.

## Phase 1: Threat Analysis (0-25%)

### Load Agents
```yaml
agents:
  - mobile-security-specialist
  - mobile-security-architect
```

### OWASP Mobile Top 10 Review
```markdown
| Risk | Description | Check |
|------|-------------|-------|
| M1 | Improper Platform Usage | APIs, permissions |
| M2 | Insecure Data Storage | Local data security |
| M3 | Insecure Communication | Network security |
| M4 | Insecure Authentication | Auth mechanisms |
| M5 | Insufficient Cryptography | Encryption usage |
| M6 | Insecure Authorization | Access control |
| M7 | Client Code Quality | Code vulnerabilities |
| M8 | Code Tampering | App integrity |
| M9 | Reverse Engineering | Obfuscation |
| M10 | Extraneous Functionality | Debug code, logs |
```

### Threat Modeling
- Identify assets (user data, tokens, keys)
- Map data flows
- Identify threat actors
- Define attack vectors

### Output
- Threat model document
- Risk prioritization
- Attack surface map

## Phase 2: Code Scanning (25-50%)

### Automated Scanning
```bash
# React Native
npx audit-ci
npm audit

# Dependency scanning
npx snyk test

# Static analysis
npx eslint --ext .ts,.tsx src/ --rule 'security/*'
```

### Manual Code Review
1. **Authentication code**
   - Token storage
   - Session management
   - Password handling

2. **API integration**
   - Request/response handling
   - Error messages
   - Rate limiting

3. **Native modules**
   - Permission usage
   - Native API calls
   - Bridge security

### Vulnerability Categories with Priority & Confidence

```markdown
P1 — Blocks Release (Confidence: High):
- S-001: Hardcoded secrets — file:line — "API key found in source"
- S-002: SQL/command injection — file:line — "Unsanitized user input in query"
- S-003: Insecure deserialization — file:line — "Untrusted data deserialized"

P2 — Fix This Sprint (Confidence: High/Medium):
- S-004: Insecure storage — file:line — "Auth token in AsyncStorage"
- S-005: Missing certificate pinning — file:line — "No pinning configured"
- S-006: Weak cryptography — file:line — "MD5 used for hashing"

P3 — Track in Backlog (Confidence: Medium/Low):
- S-007: Excessive permissions — AndroidManifest.xml:line — "CAMERA unused"
- S-008: Debug logs in production — file:line — "console.log with user data"
- S-009: Missing input validation — file:line — "No schema validation"
```

Each finding includes:
- **ID**: S-001, S-002, etc.
- **Priority**: P1 (blocks release), P2 (fix this sprint), P3 (backlog)
- **Confidence**: High (definite vulnerability), Medium (likely issue), Low (potential concern)
- **File**: exact path:line_number
- **Evidence**: code snippet showing the vulnerability
- **Remediation**: code snippet showing the fix

### Quick Scan Mode

When invoked with `--quick`, run automated checks only (Phase 2) and skip manual review:
- Dependency audit (`npm audit` / `flutter pub audit`)
- Secret scanning (grep for API keys, tokens, passwords)
- Insecure storage pattern detection
- Debug code detection
- Output: P1/P2/P3 list with file locations

### Output
- Priority-ranked vulnerability list with evidence
- Severity ratings and confidence levels
- Exact code locations (file:line)

## Phase 3: Data Security (50-75%)

### Data Storage Audit
```markdown
| Data Type | Storage Location | Encrypted | Secure |
|-----------|------------------|-----------|--------|
| Auth tokens | Keychain/Keystore | ✅ | ✅ |
| User prefs | AsyncStorage | ❌ | ⚠️ |
| Cache data | File system | ❌ | ⚠️ |
```

### Network Security
1. **Transport security**
   - HTTPS enforcement
   - Certificate pinning
   - TLS version

2. **API security**
   - Authentication headers
   - Request signing
   - Response validation

### Sensitive Data Handling
- PII identification
- Data retention policy
- Secure deletion

### Checks
```typescript
// Verify secure storage usage
// ❌ Bad
await AsyncStorage.setItem('auth_token', token)

// ✅ Good
await Keychain.setGenericPassword('auth', token, {
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
})
```

### Output
- Data security assessment
- Network security assessment
- Compliance gaps

## Phase 4: Recommendations (75-100%)

### Priority Fixes
```markdown
Critical (Fix Immediately):
1. [Issue] - [Location] - [Fix]
2. ...

High (Fix Within Sprint):
1. ...

Medium (Plan for Next Release):
1. ...
```

### Security Improvements
1. **Quick wins**
   - Enable certificate pinning
   - Remove debug logs
   - Update dependencies

2. **Medium effort**
   - Implement secure storage
   - Add input validation
   - Enable ProGuard/R8

3. **Long term**
   - Security testing pipeline
   - Penetration testing
   - Bug bounty program

### Compliance Checklist
```markdown
- [ ] GDPR compliance
- [ ] CCPA compliance
- [ ] App Store security requirements
- [ ] Play Store security requirements
```

### Output
- Prioritized fix list
- Security roadmap
- Compliance status

## Security Report

### Priority Summary
```markdown
| Priority | Count | Categories |
|----------|-------|------------|
| P1       | [N]   | Secrets: X, Injection: Y, Auth: Z |
| P2       | [N]   | Storage: X, Network: Y, Crypto: Z |
| P3       | [N]   | Permissions: X, Logging: Y |
```

### Executive Summary
- Overall security rating (A/B/C/D/F based on P1 count)
- P1 findings (blocks release)
- Compliance status

### Detailed Findings
Each vulnerability with:
- **ID and Priority**: S-001 (P1)
- **Description**: What the vulnerability is
- **File**: `src/auth/login.ts:47`
- **Evidence**: Code snippet showing the issue
- **Impact**: What an attacker could do
- **Confidence**: High / Medium / Low
- **Remediation**: Code snippet showing the fix

### Appendix
- Tools used
- Scope limitations
- References
