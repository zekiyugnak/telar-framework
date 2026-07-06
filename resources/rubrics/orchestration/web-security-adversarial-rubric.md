# Web Security Adversarial Rubric

## Purpose

Used by the always-on Adversarial Web Security Reviewer in `skills/orchestration/adversarial-code-review.md`. Extends the generic adversarial rubric with web/frontend/API-specific security failure modes.

## Reviewer mode

**Adversarial.** Same discipline as the generic rubric: fresh `Task()` instance, sees only WU spec + DoD + file scope + diff. Binary PASS/FAIL.

## Evaluation criteria

### WS. Web security failures

A WU FAILS web security review if any of:

- WS1. Authorization is enforced only on the client (hidden routes, disabled buttons, filtered UI). Server-side authz or RLS must be present for every data-mutating or data-fetching path. IDOR or broken access control (e.g., fetching `/api/resource/:id` without ownership check) → FAIL.
- WS2. User-controlled content is rendered without sanitization: `dangerouslySetInnerHTML`, unescaped template interpolation, unsanitized markdown-to-HTML, or DOM sinks (`innerHTML`, `document.write`, `eval`) reachable from URL/query/storage data.
- WS3. State-changing operations are reachable via GET, or POST/PUT/DELETE endpoints lack anti-CSRF protection (missing CSRF token, no `SameSite=Strict/Lax` cookie attribute, or token not validated server-side).
- WS4. User-supplied URLs are used in server-side fetch/redirect without an allowlist or scheme validation — enabling SSRF (internal service enumeration) or open redirect (phishing via `?next=https://evil.com`).
- WS5. Auth tokens or session credentials are stored in `localStorage`/`sessionStorage`. Cookies carrying session state must have `httpOnly`, `Secure`, and `SameSite` set. JWTs must carry `exp`; refresh tokens must be rotated on use.
- WS6. Secrets that must remain server-side (Supabase service-role key, private API keys, non-`NEXT_PUBLIC_` / non-`VITE_` env vars) appear in client bundle entrypoints, `publicRuntimeConfig`, or are interpolated into files under `public/`.
- WS7. API route or server action inputs are accepted without validation beyond type coercion: path traversal (`../`), shell metacharacters, header injection (`\r\n`), or unparameterized dynamic queries (command injection, NoSQL operator injection). SQL injection via raw interpolation is a subset.
- WS8. CORS configuration uses wildcard origin (`*`) combined with `credentials: true`, or reflects the `Origin` header unconditionally without an explicit allowlist — allowing cross-origin authenticated requests from arbitrary domains.

## Verdict format

JSON per the schema. Use rule IDs WS1-WS8. The reviewer's `reviewer` field is `"web-security"`.
