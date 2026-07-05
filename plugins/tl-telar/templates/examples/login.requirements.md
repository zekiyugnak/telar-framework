# Requirements: Email/Password Login
<!-- orchestrate-input: requirements -->
<!-- schema: requirements-input/v1 -->
<!-- EXAMPLE — generic, illustrative reference for templates/requirements.md. Not tied to any project. -->

## Vision

Let a returning user sign in with email and password and reach the authenticated area, with clear validation and error handling.

## In scope / Out of scope

- **In scope:** the login screen, client-side validation, the sign-in call, error/loading states, and navigation on success.
- **Out of scope (now):** sign-up, password reset, social/OAuth login, biometric unlock.

## Functional Requirements

| ID | Requirement | Acceptance criteria (verifiable) | Priority |
|----|-------------|----------------------------------|----------|
| F-1 | Email + password entry | Given the login screen, When it renders, Then it shows an email field, a password field (masked), and a disabled-until-valid Sign in button | Must |
| F-2 | Client-side validation | Given an invalid email or empty password, When the user submits, Then inline errors appear and no request is sent | Must |
| F-3 | Authenticate | Given valid credentials, When the user submits, Then the app calls the auth service and navigates to the home screen on success | Must |
| F-4 | Error + loading states | Given a failed sign-in, When the response returns, Then an "Invalid credentials" message shows and the form is re-enabled; a spinner shows while in flight | Must |

## UI Surfaces

| ID | Screen / flow | Platform surface | Notes / design ref |
|----|---------------|------------------|--------------------|
| UI-1 | Login screen (email, password, submit, error/loading) | iOS / Android | {{link to mockup, or "n/a"}} |

## Non-Functional Requirements

- **Performance:** submit feedback within 100ms (spinner); no UI jank.
- **Security / privacy:** never log credentials; password field masked; token stored in secure storage.
- **Accessibility:** fields labeled for screen readers; errors not conveyed by color alone.
- **i18n / l10n:** all strings localizable.

## Decisions & Constraints

- **Architecture decisions:** {{link to RESEARCH.md / ADRs, or inline}}
- **Tech stack / non-negotiables:** {{framework (RN/Flutter), state mgmt, auth backend}}
- **Dependencies:** an existing auth service / `signIn(email, password)` API.

## Open Questions

- [ ] {{anything unresolved}}

## Change Log

| Date | Change | Triggered by |
|------|--------|--------------|
| {{ISO date}} | Initial example | — |
