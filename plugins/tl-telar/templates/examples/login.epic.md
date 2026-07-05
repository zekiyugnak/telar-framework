# Epic: Email/Password Login
<!-- orchestrate-input: epic -->
<!-- schema: epic-input/v1 -->
<!-- EXAMPLE — generic, illustrative reference for templates/epic.md. Not tied to any project.
     Run: /tl-telar:orchestrate --epic templates/examples/login.epic.md -->

## Intent

Deliver an email/password login screen: validated input, an authenticate call, clear error/loading states, and navigation to home on success. Generic single-feature example showing how an epic decomposes into Work Units.

## Requirements & Decisions

- **Requirements:** F-1..F-4 (see `login.requirements.md`); UI-1.
- **Key decisions / constraints:** {{framework (RN/Flutter), state mgmt, auth backend, secure token storage}}.
- **Depends on (other epics):** an existing auth service exposing `signIn(email, password)`.

## Tasks

### T1: Login screen UI + client-side validation

- **spec:** Build the login screen with email + masked password fields, a Sign in button, and inline validation.
- **dod:**
  - [ ] Renders email field, password field (masked), and a Sign in button disabled until inputs are valid (F-1)
  - [ ] Given an invalid email or empty password, When submit, Then inline errors show and no request is sent (F-2)
  - [ ] All strings are localizable; fields have accessibility labels
- **file_scope:**
  - src/screens/LoginScreen.tsx
  - src/screens/__tests__/LoginScreen.test.tsx
- **deps:** []
- **checkpoint:** false

### T2: Authenticate + error/loading states + navigation

- **spec:** Wire submit to the auth service, handle loading and failure, and navigate home on success.
- **dod:**
  - [ ] Given valid credentials, When submit, Then `signIn()` is called and the app navigates to Home on success (F-3)
  - [ ] Given a failed sign-in, When the response returns, Then "Invalid credentials" shows and the form re-enables (F-4)
  - [ ] A spinner shows while the request is in flight; credentials are never logged
- **file_scope:**
  - src/hooks/useLogin.ts
  - src/hooks/__tests__/useLogin.test.ts
- **deps:** [T1]
- **checkpoint:** false

## Risks & Mitigations

| Risk | Likelihood (L/M/H) | Impact (L/M/H) | Mitigation |
|------|--------------------|----------------|------------|
| Token stored insecurely | L | H | Use secure storage; never persist plaintext |
| Credential leakage in logs | L | H | Scrub; never log password or token |

## Epic Acceptance Criteria

- [ ] A user can sign in with valid credentials and land on Home
- [ ] Invalid input is blocked client-side; failed auth shows a clear error
- [ ] No credentials are logged; token stored securely

## Amendment Log

| Date | Change | Triggered by |
|------|--------|--------------|
| {{ISO date}} | Initial example | — |
