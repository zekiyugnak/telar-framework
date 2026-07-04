---
id: simplicity-first
category: rule
alwaysApply: true
tags: [simplicity, anti-patterns, restraint, code-quality, kiss]
---

# Simplicity First

Write the minimum code that solves the problem. Nothing speculative. If 200 lines could be 50, rewrite it.

## Rule

When implementing any feature or fix:

1. **No features beyond what was asked.** If REQUIREMENTS.md says F-3 needs a "Forgot password" link, do not also add social login, magic links, or a password strength meter. Add those when there is a requirement for them.

2. **No abstractions for single-use code.** Do not build a `ThemeProvider` configurable via 12 props when one constant export covers every screen today. Do not introduce a navigation wrapper "in case we swap React Navigation for Expo Router later" — wait until you actually swap.

3. **No flexibility or configurability that was not requested.** A `Button` component with `variant`, `size`, `loading`, `iconLeft`, `iconRight`, `fullWidth`, `as` polymorphism, and `analyticsId` props is overengineered if the design system only specifies primary, secondary, and disabled. Ship those three; add the rest when REQUIREMENTS.md asks.

4. **No error handling for impossible scenarios.** Do not add `try/catch` around code that cannot throw. Do not validate internal-only inputs that already have TypeScript / Dart types. Validate at system boundaries (user input, API responses, deeplink params, native bridge calls) — not between your own functions.

5. **No premature platform splits.** Do not write `Platform.OS === 'ios' ? A : B` until iOS and Android genuinely diverge. Do not create separate `.ios.tsx` / `.android.tsx` files for code that is identical today.

## The Senior-Engineer Test

Before marking a task done, ask: **"Would a senior mobile engineer reading this PR say it is overcomplicated?"**

If the answer is yes — or "maybe" — rewrite it smaller. Common smells:

- A new file for one function that is used in one place
- A `utils/` helper that is called once, ten lines below where it's defined
- A custom hook that wraps a single `useState` with no added behavior
- A Riverpod / Zustand provider for state that never leaves one screen
- An interface / abstract class with exactly one implementation
- A configuration object passed to a function that has one caller

Inline it. Delete it. Ship the small version.

## Why

Overengineered mobile code costs more than overengineered backend code:

- **Bundle size** — every abstraction layer ships to every device, every install
- **Cold-start time** — more modules to parse and instantiate on app launch
- **Battery and memory** — extra wrappers and providers re-render and allocate
- **Reviewability** — reviewers cannot tell whether a 600-line PR is correct; they can tell whether a 60-line PR is correct
- **Onboarding cost** — every speculative abstraction is a new concept the next developer must learn before they can change the screen they were sent to fix

## Exceptions

This rule does not override:

- **Security** — never simplify away input validation at trust boundaries (see `rules/mobile-security.md`)
- **Accessibility** — never simplify away `accessibilityLabel`, semantic roles, or screen-reader support
- **Platform conventions** — never simplify away iOS HIG / Material 3 compliance to share one component (see `rules/platform-conventions.md`)
- **Quality gates** — never simplify away tests, types, or lints to ship faster (see `rules/quality-gates.md`)

When in doubt, simplicity loses to security, accessibility, and platform fit. It wins against everything else.

## Related

- `rules/codebase-first.md` — reuse existing components instead of building new ones
- `skills/brainstorm-first.md` — surfaces simpler alternatives before implementation
- `skills/verification-before-completion.md` — confirms the small version actually works

## Attribution

Adapted from the [karpathy-guidelines](https://github.com/forrestchang/andrej-karpathy-skills) plugin by forrestchang, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls. The other three Karpathy principles (Think Before Coding, Surgical Changes, Goal-Driven Execution) are already covered by `skills/brainstorm-first.md`, `rules/codebase-first.md`, and `skills/verification-before-completion.md` respectively.
