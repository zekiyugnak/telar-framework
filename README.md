# Telar

> **The agentic engineering framework** — plan, build, review, and ship, with agents.
> By Zeki Yugnak · v0.1.0 — 37 agents, 95 skills, 23 commands, 4 hooks, 7 rules, 19 scripts

Telar is a multi-agent engineering framework for Claude Code that takes a feature from idea to production — orchestrated planning, adversarial review gates, a persistent knowledge base, and cross-model verification. Its first edition targets **cross-platform mobile** (**React Native** & **Flutter**) with deep native integration.

## Installation

```bash
# Add the marketplace
claude plugin marketplace add zekiyugnak/telar-framework

# Install the plugin
claude plugin install tl-telar@telar
```

After installation, restart Claude Code to load the plugin.

## Workflow

The recommended development workflow:

1. **Explore** — Always explore the existing codebase first (`codebase-first` rule, auto-applied)
2. **Brainstorm** — Research before coding: `brainstorm-first` skill produces `RESEARCH.md`
3. **Plan** — Decompose into atomic tasks: `plan-and-track` skill produces `PLAN.md` + `PROGRESS.md`
4. **Build** — Iterate with simulator verification: `iterative-build-loop` skill
5. **Debug** — When failures occur, find root cause before fixing (`systematic-debugging` skill)
6. **Verify** — Require fresh evidence before claiming done (`verification-before-completion` skill)
7. **Review** — Two-stage gates: spec compliance + code quality (`review-gates` skill)
8. **Commit** — Mobile-specific conventional commits (`mobile-commit-convention` skill)

### Quick Start
- New app: `/tl-telar:create-app [description]`
- Add feature: `/tl-telar:add-feature [feature]`
- Code review: `/tl-telar:review-code [path]`
- Review a plan (adversarial gate): `/tl-telar:review-plan [--latest]`
- End-to-end orchestrated build: `/tl-telar:orchestrate <task>`
- Resume in-progress orchestrated plan: `/tl-telar:resume`
- Set up orchestration (framework detection): `/tl-telar:setup-orchestration`
- Prime KB facts into context: `/tl-telar:prime [--files <glob>] [--keywords <kw>] [--work-type <t>]`
- Capture learnings to KB: `/tl-telar:self-reflect [<days>]`
- Design review gate (collaborative, 6 reviewers): `/tl-telar:review-design [--latest]`
- External AI tools health check: `/tl-telar:external-tools-health`

## Orchestrated Mode (v0.1.0)

Opt-in multi-agent orchestration. Strictly opt-in: legacy commands above work unchanged until you run setup.

```
/tl-telar:setup-orchestration   # one-time opt-in: framework detection + .tl-telar/ skeleton
/tl-telar:orchestrate <task>    # design gate → plan gate → 4-phase execution per work unit
/tl-telar:resume                # continue an interrupted orchestrated run
/tl-telar:self-reflect          # capture learnings into the knowledge base after a PR
```

What fires automatically inside an orchestrated run:

- **Design Review Gate** — 6 collaborative reviewers (PM/Architect/Designer/Security-Design/CTO/Mobile-Platform) on RESEARCH.md before any plan is drafted
- **Plan Review Gate** — 3 adversarial reviewers (Feasibility/Completeness/Scope) on PLAN.md, binary PASS/FAIL
- **4-phase loop per work unit** — IMPLEMENT → VALIDATE (quality gates) → REVIEW (fresh adversarial reviewers) → COMMIT
- **In-session progress tree** — a compact terminal render (phase line per transition + WU tree at boundaries) so you see steps and cycles at a glance instead of verbose dumps; detail stays in `.tl-telar/context/execution-state.md`
- **State persistence** — 3-file state under `.tl-telar/`; a SessionStart hook re-primes context after compaction or restart
- **Knowledge base** — typed JSONL facts auto-primed into context each session; populated via `/tl-telar:self-reflect`

**External AI (Phase β/γ, disabled by default):** Codex/Gemini adapters with a budget circuit breaker ($1/task, $10/session) and cross-model review (the model that wrote a diff never reviews it). Enable in `.tl-telar/external-tools.yaml`.

## Authoring inputs for `/tl-telar:orchestrate`

`orchestrate` is only as reliable as the document you feed it. Copy-paste templates live in **`templates/`** (plugin root); a complete worked example is in `templates/examples/`.

### The document chain

```
REQUIREMENTS  (program: what & why, all features)   templates/requirements.md
      │   slice ONE feature
      ▼
EPIC          (one feature: tasks = work units)      templates/epic.md
      │
      ▼
/tl-telar:orchestrate --epic <path>   → Plan Review Gate → WUs → 4-phase loop
```

One **requirements** doc can cover many features. Each feature you actually build becomes one **epic** — and an epic is exactly what `--epic` consumes. "Plan" and "epic" are the same artifact here; there is no separate plan template.

### Three ways to start

| Mode | Command | When |
|---|---|---|
| Free-text | `/tl-telar:orchestrate <description>` | No plan yet — orchestrator drafts one |
| **Epic file** | `/tl-telar:orchestrate --epic templates/epic.md` | A prepared single-feature epic |
| Plan file | `/tl-telar:orchestrate --plan-file <PLAN.md>` | You already keep a WU-decomposable plan |

`--epic`/`--plan-file` skip *drafting* but never the mandatory 3-reviewer **Plan Review Gate**.

### Why each epic field exists (this is the correctness guarantee)

Every field is read by a specific gate — fill them all or that gate fails:

| Field | Read by | If missing / wrong |
|---|---|---|
| `## Intent` | Plan Review · Scope-Alignment reviewer | gate stops, asks for the original request |
| task `spec` (no "and") | WU decomposition (single responsibility) | reviewer FAILs an over-broad WU |
| task `dod` (verifiable) | Phase 3 adversarial review (per criterion) + COMMIT gate | unverifiable → cannot pass |
| task `file_scope` | Phase 2 content-aware scope check | out-of-scope edit → VALIDATION FAIL |
| task `deps` | WU DAG ordering | wrong build order / false parallelism |
| `checkpoint` | interactive pause / unattended pre-flight | mid-cycle surprise stop |

Tip: pull each task's `dod` straight from your spec's Given-When-Then acceptance criteria — see the worked example `templates/examples/login.epic.md`.

### Readiness checklist (tick before running)

- [ ] **One feature only** — not a whole program/roadmap (split multi-feature work into one epic per feature)
- [ ] `## Intent` is present and specific
- [ ] Every task has all five fields: `spec`, `dod`, `file_scope`, `deps`, `checkpoint`
- [ ] Every `dod` item is verifiable (a command or a human can check it)
- [ ] Parallel tasks (no `deps` between them) have **disjoint** `file_scope`
- [ ] Surface is RN/Flutter mobile (public web / pure-backend work is outside this plugin's scope)

## Feature Blueprints

Ready-to-use implementation blueprints in `skills/blueprints/`:

| Blueprint | Description |
|-----------|-------------|
| `auth-flow` | Login, signup, forgot password, social auth |
| `crud-list` | Master-detail with CRUD, pagination, swipe actions |
| `chat-feature` | Real-time chat with typing indicators, read receipts |
| `settings-screen` | Settings with toggles, account management |
| `onboarding-flow` | Multi-step onboarding with permission requests |

Each blueprint includes RN (TypeScript) + Flutter (Dart) implementations, Supabase backend SQL, tests, and accessibility.

## Simulator Automation

Unified simulator/emulator control via `scripts/sim-control.sh`:

```bash
sim-control.sh list                    # List available simulators
sim-control.sh boot                    # Boot default simulator
sim-control.sh screenshot output.png   # Take screenshot
sim-control.sh launch com.app.id       # Launch app
sim-control.sh deeplink myapp://path   # Open deep link
```

Auto-detects iOS Simulator vs Android Emulator.

## Features

### Specialized Agents (37)

#### Core Platform Experts

| Agent | Icon | Purpose |
|-------|------|---------|
| `react-native-expert` | ⚛️ | React Native cross-platform specialist |
| `flutter-expert` | 🦋 | Flutter/Dart cross-platform specialist |

#### Native Platform Support

| Agent | Icon | Purpose |
|-------|------|---------|
| `ios-native-bridge` | 🍎 | iOS native code for RN/Flutter bridges |
| `android-native-bridge` | 🤖 | Android native code for RN/Flutter bridges |

#### Cross-Cutting Specialists

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-navigation-architect` | 🧭 | Navigation patterns and deep linking |
| `mobile-state-management` | 🔄 | State management solutions |
| `mobile-performance-optimizer` | 🚀 | Performance profiling and optimization |
| `mobile-ui-ux-specialist` | 🎨 | UI/UX design and implementation |
| `mobile-accessibility-expert` | ♿ | Accessibility compliance and best practices |
| `mobile-security-specialist` | 🔐 | App security implementation |
| `mobile-offline-architect` | 📴 | Offline-first architecture |
| `mobile-animations-specialist` | ✨ | Animations and micro-interactions |

#### Build & Deployment

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-cicd-engineer` | ⚙️ | CI/CD pipeline setup and maintenance |
| `ios-app-store-specialist` | 🍏 | App Store submission and compliance |
| `google-play-specialist` | ▶️ | Play Store submission and policies |
| `mobile-code-signing-expert` | 🔑 | Code signing and certificates |
| `mobile-ota-updates-specialist` | 📲 | OTA updates (CodePush, Expo Updates) |
| `mobile-release-manager` | 📦 | Release orchestration and versioning |

#### Testing

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-unit-testing-expert` | 🧪 | Unit testing strategies |
| `mobile-e2e-testing-expert` | 🎯 | E2E testing with Detox/Maestro |
| `mobile-device-testing` | 📱 | Device testing and compatibility |
| `mobile-performance-testing` | 📊 | Performance benchmarking |

#### Backend Integration

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-api-integration` | 🔌 | API integration and networking |
| `mobile-push-notifications` | 🔔 | Push notification implementation |
| `mobile-auth-specialist` | 🔓 | Authentication flows |
| `mobile-storage-specialist` | 💾 | Local storage and persistence |

#### Backend Architecture

| Agent | Icon | Purpose |
|-------|------|---------|
| `supabase-expert` | ⚡ | Supabase backend integration |
| `mobile-backend-architect` | 🏗️ | Backend architecture for mobile |
| `mobile-security-architect` | 🛡️ | Security architecture design |

#### AI & Advanced Features

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-ai-integration` | 🤖 | AI/ML integration in mobile apps |
| `mobile-ar-vr-specialist` | 👓 | AR/VR experiences |
| `mobile-realtime-specialist` | ⏱️ | Real-time communication |

#### Orchestration & Knowledge (v0.1.0)

| Agent | Icon | Purpose |
|-------|------|---------|
| `mobile-orchestrator` | 🎼 | End-to-end orchestrated execution: gates, WU DAG, 4-phase loop |
| `mobile-knowledge-curator` | 📚 | KB curation: dedup, confidence promotion, staleness sweep |
| `mobile-architect-adversarial` | 🏛️ | Adversarial-mode architecture reviewer (Plan + Design gates) |

See [AGENTS.md](AGENTS.md) for the auto-generated full directory of all 37 agents.

### Commands (23 Workflows)

| Command | Description |
|---------|-------------|
| `/tl-telar:create-app` | Create new cross-platform app with brainstorming and architecture |
| `/tl-telar:add-feature` | Add feature with exploration, brainstorming, planning, and review |
| `/tl-telar:migrate-app` | Migrate native app to cross-platform |
| `/tl-telar:upgrade-deps` | Safe dependency upgrades |
| `/tl-telar:review-code` | Two-stage code review with spec compliance + quality |
| `/tl-telar:review-plan` | Adversarial 3-reviewer gate on implementation plans |
| `/tl-telar:orchestrate` | End-to-end orchestrated 4-phase build loop |
| `/tl-telar:resume` | Resume an in-progress orchestrated plan (recovery) |
| `/tl-telar:setup-orchestration` | Interactive setup: framework detection + .tl-telar/ skeleton |
| `/tl-telar:audit-security` | Security audit with P1/P2/P3 priority ranking |
| `/tl-telar:audit-accessibility` | Accessibility audit with automated scan + manual checklist |
| `/tl-telar:optimize-perf` | Performance optimization |
| `/tl-telar:test-app` | Comprehensive testing |
| `/tl-telar:setup-e2e` | E2E testing setup |
| `/tl-telar:release-app` | Full release workflow |
| `/tl-telar:setup-cicd` | CI/CD pipeline setup |
| `/tl-telar:setup-ota` | OTA updates configuration |
| `/tl-telar:design-system` | Design system setup |
| `/tl-telar:prime` | Prime KB facts into context (5-category retrieval) |
| `/tl-telar:self-reflect` | Capture learnings to KB (3-phase pipeline with user-approval gate) |
| `/tl-telar:review-design` | Collaborative 6-reviewer design gate (PM/Architect/Designer/Security-Design/CTO/Mobile-Platform) |
| `/tl-telar:external-tools-health` | Real-time health of Codex/Gemini adapters (Phase β, opt-in) |

### Skills (95 Reference Modules)

#### React Native (8 skills)
- `rn-navigation` - React Navigation patterns and deep linking
- `rn-state-management` - Redux, Zustand, MobX integration
- `rn-native-modules` - Native module development
- `rn-new-architecture` - Fabric, TurboModules, Codegen
- `rn-styling` - Styling approaches and design systems
- `rn-animations` - Reanimated, Moti, Skia animations
- `rn-testing` - Jest, Testing Library patterns
- `rn-expo` - Expo workflow and managed apps

#### Flutter (8 skills)
- `flutter-navigation` - GoRouter, auto_route patterns
- `flutter-state-management` - Riverpod, BLoC, Provider
- `flutter-platform-channels` - Platform-specific code
- `flutter-flavors` - Build flavors and environments
- `flutter-styling` - Theming and design systems
- `flutter-animations` - Implicit, explicit, custom animations
- `flutter-testing` - Widget, integration, golden tests
- `flutter-packages` - Package development and publishing

#### Cross-Platform Design (10 skills)
- `responsive-design` - Responsive layouts across devices
- `platform-adaptive-ui` - Platform-specific UI adaptations
- `theming-dark-mode` - Theming and dark mode support
- `internationalization` - i18n and l10n implementation
- `accessibility-patterns` - A11y compliance patterns
- `error-handling-mobile` - Error boundaries and reporting
- `networking-patterns` - API clients and caching
- `offline-sync-patterns` - Offline-first data sync
- `secure-storage` - Secure storage solutions
- `biometric-auth` - Biometric authentication

#### Performance (6 skills)
- `list-optimization` - FlatList/ListView optimization
- `image-optimization` - Image loading and caching
- `bundle-optimization` - Bundle size reduction
- `startup-optimization` - App startup performance
- `memory-management` - Memory profiling and optimization
- `render-optimization` - Render performance tuning

#### Deployment (6 skills)
- `ios-provisioning` - iOS certificates and provisioning
- `android-signing` - Android keystore and signing
- `app-store-guidelines` - App Store Review Guidelines
- `play-store-policies` - Google Play policies
- `staged-rollouts` - Phased rollout strategies
- `crash-reporting` - Crash reporting setup

#### Testing (4 skills)
- `testing-pyramid-mobile` - Mobile testing strategy
- `mock-strategies` - Mocking for mobile tests
- `snapshot-testing` - UI snapshot testing
- `ci-testing-integration` - CI testing pipelines

#### Supabase & Backend (6 skills)
- `supabase-auth` - Supabase authentication
- `supabase-database` - PostgreSQL with Supabase
- `supabase-storage` - File storage patterns
- `supabase-realtime` - Real-time subscriptions
- `supabase-edge-functions` - Edge function development
- `graphql-mobile-patterns` - GraphQL client patterns

#### Payments (4 skills)
- `in-app-purchases` - IAP implementation
- `revenucat-integration` - RevenueCat subscription management
- `stripe-mobile` - Stripe mobile integration
- `mobile-ads-integration` - Ad SDK integration

#### Maps & Location (3 skills)
- `maps-integration` - Google Maps, MapKit integration
- `location-services` - Location tracking and geofencing
- `geospatial-features` - Geospatial data handling

#### AI & Advanced (3 skills)
- `ai-api-integration` - AI API integration patterns
- `image-video-generation` - AI image/video features
- `ar-mobile-patterns` - ARKit/ARCore patterns

#### Workflow (7 skills)
- `brainstorm-first` - Enforce research phase before implementation
- `plan-and-track` - Task decomposition with PLAN.md/PROGRESS.md
- `review-gates` - Two-stage review: spec compliance + code quality
- `iterative-build-loop` - Multi-session feature building with baton handoff
- `mobile-commit-convention` - Mobile-specific conventional commits
- `systematic-debugging` - Root-cause-first debugging methodology
- `verification-before-completion` - Fresh evidence gate before done claims

#### Blueprints (5 skills)
- `blueprints/auth-flow` - Complete authentication flow
- `blueprints/crud-list` - Master-detail CRUD pattern
- `blueprints/chat-feature` - Real-time chat feature
- `blueprints/settings-screen` - Settings with toggles and account mgmt
- `blueprints/onboarding-flow` - Multi-step onboarding

#### Design & Meta (3 skills)
- `design-system-persistence` - Hierarchical design tokens (MASTER.md + per-screen)
- `create-skill` - Meta-skill for creating new skills in this plugin

## Usage Examples

### Creating a New App
```
Ask: "Create a Flutter fitness tracking app with Supabase backend"
Agent: flutter-expert + supabase-expert
Command: /tl-telar:create-app fitness tracking app with Supabase
```

### Adding Features
```
Ask: "Add push notifications with deep linking support"
Agent: mobile-push-notifications + mobile-navigation-architect
Command: /tl-telar:add-feature push notifications with deep linking
```

### Performance Optimization
```
Ask: "My app is slow on older Android devices"
Agent: mobile-performance-optimizer analyzes and fixes bottlenecks
Command: /tl-telar:optimize-perf
```

### Setting Up CI/CD
```
Ask: "Set up GitHub Actions for my React Native app"
Agent: mobile-cicd-engineer provides complete pipeline
Command: /tl-telar:setup-cicd
```

### App Store Release
```
Ask: "Release my app to iOS App Store and Google Play"
Agent: ios-app-store-specialist + google-play-specialist
Command: /tl-telar:release-app to App Store and Play Store
```

### Security Audit
```
Ask: "Audit my app for security vulnerabilities"
Agent: mobile-security-specialist + mobile-security-architect
Command: /tl-telar:audit-security
```

### Migration
```
Ask: "Migrate my native iOS app to Flutter"
Agent: flutter-expert + ios-native-bridge
Command: /tl-telar:migrate-app from native iOS to Flutter
```

### OTA Updates Setup
```
Ask: "Set up CodePush for my React Native app"
Agent: mobile-ota-updates-specialist
Command: /tl-telar:setup-ota CodePush
```

## Supported Languages, Frameworks & Tooling

### Languages
- **TypeScript** / **JavaScript** — React Native, Expo, tooling
- **Dart** — Flutter
- **Swift** — iOS native modules & bridges
- **Kotlin** — Android native modules & bridges
- **Objective-C** — legacy iOS bridge interop
- **Java** — legacy Android bridge interop
- **SQL** (PostgreSQL) — Supabase schema, RLS, edge functions
- **Bash** / **YAML** — CI/CD pipelines and automation

### Cross-Platform Frameworks (Primary)
- **React Native** (TypeScript/JavaScript) — iOS, Android
- **Expo** — managed workflow, EAS Build/Submit/Update
- **Flutter** (Dart) — iOS, Android, Web, Desktop

### Native UI Toolkits (Bridge Support)
- **SwiftUI** / UIKit — iOS native
- **Jetpack Compose** / Android Views — Android native

### State Management
- **React Native:** Redux Toolkit, Zustand, MobX, React Query / TanStack Query
- **Flutter:** Riverpod, BLoC / Cubit, Provider

### Navigation
- **React Native:** React Navigation, Expo Router
- **Flutter:** GoRouter, auto_route

### Backend & Data
- **Supabase** — Auth, Postgres, Storage, Realtime, Edge Functions
- **Firebase** — Auth, Firestore, Cloud Functions, Cloud Messaging
- **REST** & **GraphQL** APIs — custom backends and clients

### Payments & Monetization
- **In-App Purchases** (StoreKit / Google Play Billing)
- **RevenueCat** — subscription management
- **Stripe** — mobile payments
- Ad SDKs (AdMob and equivalents)

### Maps, Location & AR
- **Google Maps**, **Apple MapKit**
- Location services & geofencing
- **ARKit** (iOS), **ARCore** (Android)

### Testing
- **React Native:** Jest, React Native Testing Library, **Detox**, **Maestro**
- **Flutter:** widget, integration, and golden tests
- Snapshot / UI testing, mocking strategies, CI test integration

### CI/CD, Release & OTA
- **CI/CD:** GitHub Actions, Fastlane (build, sign, test, deploy)
- **Code signing:** iOS provisioning & certificates, Android keystore/signing
- **OTA updates:** CodePush, Expo Updates, **Shorebird**
- **Distribution:** iOS App Store, Google Play Store, TestFlight, Firebase App Distribution, Expo EAS

### AI & Advanced
- AI/ML API integration (text, image, and video generation patterns)
- Real-time communication patterns
- Offline-first architecture & sync

### Optional External AI Delegation (opt-in, disabled by default)
- **OpenAI Codex** and **Google Gemini** CLIs for cross-model implementation/review

## Using the Workflows

### Quick Start Commands

```
/tl-telar:create-app fitness tracker with Supabase backend
```
This runs the full workflow automatically: brainstorm → plan → scaffold → build → CI/CD.

```
/tl-telar:add-feature push notifications with deep linking
```
This runs: explore codebase → brainstorm → plan → build → review gates.

### Using Workflow Skills Individually

The skills can also be invoked by referencing them directly:

**1. Brainstorm First** — Ask Claude to brainstorm before coding:
```
"I want to add a chat feature. Let's brainstorm first and produce a RESEARCH.md"
```
This triggers `brainstorm-first` and produces `RESEARCH.md` with platform analysis, architecture options, and risk assessment.

**2. Plan and Track** — After brainstorming:
```
"Now let's create a PLAN.md with atomic tasks for the chat feature"
```
This triggers `plan-and-track` and produces `PLAN.md` + `PROGRESS.md`.

**3. Review Gates** — After implementation:
```
/tl-telar:review-code src/features/chat
```
This runs two-stage review: spec compliance (checks PLAN.md criteria) then code quality.

**4. Commit Convention** — When committing:
```
"Commit this with the mobile commit convention"
```
Produces: `feat(rn): add real-time chat with typing indicators`

### Automatic Behaviors (no action needed)

These are always active via `settings.json`:

- **codebase-first rule** — Reminds Claude to read `package.json`/`pubspec.yaml` and scan existing architecture before generating code
- **platform-conventions rule** — Enforces Apple HIG / Material Design 3 touch targets, navigation patterns, etc.
- **explore-before-generate hook** — Fires on every prompt, detects your project type and reminds to check existing patterns

### Simulator Automation

From your project directory:
```bash
bash scripts/sim-control.sh list          # see available devices
bash scripts/sim-control.sh boot          # boot default simulator
bash scripts/sim-control.sh screenshot    # take screenshot
bash scripts/sim-control.sh deeplink myapp://chat/123
```

### Blueprint Shortcuts

When adding common features, Claude will auto-suggest matching blueprints:
```
/tl-telar:add-feature authentication
```
Claude detects this matches `skills/blueprints/auth-flow.md` and offers the full RN + Flutter + Supabase implementation as a starting point.

The five blueprints cover: **auth-flow**, **crud-list**, **chat-feature**, **settings-screen**, **onboarding-flow**.

## Best Practices

1. **Choose Framework Early** - Use `flutter-expert` or `react-native-expert` to assess requirements
2. **Start with Architecture** - Use `mobile-navigation-architect` and `mobile-state-management` before coding
3. **Plan Backend Integration** - Use `supabase-expert` or `mobile-backend-architect` for data layer
4. **Set Up CI/CD Early** - Use `mobile-cicd-engineer` for automated builds from day one
5. **Test on Real Devices** - Use `mobile-device-testing` for device-specific issues
6. **Optimize Before Release** - Use `mobile-performance-optimizer` with profiler data
7. **Plan Store Submission** - Use `ios-app-store-specialist` and `google-play-specialist` for compliance

## Plugin Structure

```
telar-framework/
├── CLAUDE.md                    # Entry point for Claude Code
├── AGENTS.md                    # Auto-generated agent directory
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/ (37)
├── commands/ (23)
│   ├── create-app.md            # Modified: brainstorming phase
│   ├── add-feature.md           # Modified: exploration + brainstorming + review gates
│   ├── review-code.md           # Modified: two-stage review
│   ├── audit-security.md        # Modified: P1/P2/P3 ranking
│   ├── audit-accessibility.md   # NEW: active accessibility audit
│   └── ... (9 more commands)
├── skills/ (~95)
│   ├── brainstorm-first.md      # NEW: research before code
│   ├── plan-and-track.md        # NEW: task decomposition
│   ├── review-gates.md          # NEW: two-stage review
│   ├── mobile-commit-convention.md  # NEW: commit format
│   ├── design-system-persistence.md # NEW: design tokens
│   ├── create-skill.md          # NEW: meta-skill
│   ├── blueprints/              # NEW: feature blueprints
│   │   ├── README.md
│   │   ├── auth-flow.md
│   │   ├── crud-list.md
│   │   ├── chat-feature.md
│   │   ├── settings-screen.md
│   │   └── onboarding-flow.md
│   └── ... (existing skills)
├── rules/ (7)
│   ├── codebase-first.md        # NEW: explore before generate
│   ├── platform-conventions.md  # NEW: HIG + Material Design 3
│   └── ... (3 existing rules)
├── hooks/ (4)
│   ├── explore-before-generate.sh  # NEW: codebase reminder
│   └── ... (3 existing hooks)
├── scripts/ (19)
│   ├── sim-control.sh           # NEW: simulator automation
│   ├── project-detect.sh        # NEW: project type detection
│   ├── validate-blueprints.js   # NEW: blueprint validation
│   └── ... (5 existing scripts)
├── resources/
│   ├── decision-trees/
│   ├── platform-guides/
│   ├── checklists/
│   └── reasoning-rules/
└── settings.json
```

## Contributing

To extend this plugin:
1. Add new agents in `agents/` directory
2. Add new skills in `skills/` directory
3. Add new commands in `commands/` directory

## Version History

- **v0.1.0** - Initial release: 37 agents, 95 skills, 23 commands, 4 hooks, 7 rules, 19 scripts; orchestration suite (plan + design review gates, 4-phase execution loop, quality gates, state persistence + recovery, knowledge base + /self-reflect, external AI delegation, cross-model review) for cross-platform mobile (React Native & Flutter)

## License

MIT
