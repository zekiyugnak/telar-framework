---
id: blueprints-index
category: skill
tags: [blueprint, index, scaffolding, feature]
capabilities:
  - Blueprint discovery and selection
useWhen:
  - Looking for a feature blueprint
  - Starting a common mobile feature
---

# Feature Blueprints

Ready-to-use implementation blueprints for common mobile features. Each blueprint includes:

- **File manifest** — exact files to create
- **React Native implementation** (TypeScript)
- **Flutter implementation** (Dart)
- **Supabase backend setup** (SQL)
- **Tests** — unit and integration
- **Accessibility** — built-in a11y checklist

## Available Blueprints

| Blueprint | Description | Key Patterns |
|-----------|-------------|--------------|
| [auth-flow](./auth-flow.md) | Login, signup, forgot password, social auth | Secure token storage, biometrics, Supabase Auth |
| [crud-list](./crud-list.md) | Master-detail with CRUD, pagination, swipe | Optimistic updates, infinite scroll, empty states |
| [chat-feature](./chat-feature.md) | Real-time messaging, typing indicators | Supabase Realtime, presence, read receipts |
| [settings-screen](./settings-screen.md) | Settings with toggles, account management | Local persistence, theme selection, danger zone |
| [onboarding-flow](./onboarding-flow.md) | Multi-step intro with permissions | Pagination, skip, permission requests, completion tracking |

## Usage

1. Identify which blueprint matches your feature
2. Copy the file manifest and adjust paths to your project
3. Follow the implementation for your platform (RN or Flutter)
4. Run the Supabase SQL to set up the backend
5. Verify the accessibility checklist

Blueprints are designed to be adapted, not copied verbatim. Adjust to match your project's existing patterns (state management, styling, navigation).
