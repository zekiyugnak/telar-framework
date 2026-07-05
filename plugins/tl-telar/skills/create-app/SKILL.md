---
name: "create-app"
description: "Create a new cross-platform mobile application with requirements gathering, brainstorming, architecture, navigation, state management, and CI/CD setup."
source_type: "command"
source_file: "commands/create-app.md"
---

# create-app

Migrated from `commands/create-app.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:create-app`; invoke it as `$create-app` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Create Mobile App

> Artifacts (REQUIREMENTS.md, RESEARCH.md, PLAN.md, PROGRESS.md) are written under `tl-telar-spec/changes/<id>/` — see `skills/requirements-gather.md` → "Step 0" for change-id/domain resolution. Once the feature is complete, run `node scripts/tl-telar-spec-archive.js <change-id>` to merge into `tl-telar-spec/truth/` and archive the change folder.

Create a new cross-platform mobile application. Begins with requirements gathering before any technical decisions.

## Phase 1: Requirements (0-15%)

### Load Skills
```yaml
skills:
  - requirements-gather
```

### Step 0: Document Check

**Ask the user:**

> Do you have an existing requirements document, PRD, or design document for this app?
> - **Yes** → Proceed with **Document-Driven Mode** in `requirements-gather`
> - **No** → Proceed with **From Scratch Mode** in `requirements-gather`

### Step 1: Gather Requirements

Invoke `requirements-gather` skill:
- **Document-Driven Mode**: Accept document, extract decisions, run gap analysis, produce REQUIREMENTS.md
- **From Scratch Mode**: Ask core questions interactively, produce REQUIREMENTS.md

In both cases, also ask:
- "Do you have Figma designs or wireframes?" → catalogue in REQUIREMENTS.md Design Assets table

### Output
- REQUIREMENTS.md (single source of truth for what to build)

---

## Phase 2: Discovery (15-30%)

### Load Skills
```yaml
skills:
  - brainstorm-first
  - plan-and-track
```

### Step 2: Technical Research

Invoke `brainstorm-first` (reads REQUIREMENTS.md):
- Produces Requirements-Architecture Impact analysis
- Only deliberates on areas not pre-decided in REQUIREMENTS.md
- Produces RESEARCH.md

### Step 3: Planning

Invoke `plan-and-track` (reads REQUIREMENTS.md + RESEARCH.md):
- Breaks project setup into atomic tasks
- Each task references F-x / UI-x from REQUIREMENTS.md
- Respects phase order from REQUIREMENTS.md
- Produces PLAN.md + PROGRESS.md

### Output
- RESEARCH.md (architecture decisions)
- PLAN.md (setup tasks with requirement references)
- PROGRESS.md (initialized)

---

## Phase 3: Architecture (30-45%)

### Load Relevant Agents
```yaml
agents:
  - react-native-expert OR flutter-expert    # Based on RESEARCH.md
  - mobile-navigation-architect
  - mobile-state-management
  - mobile-backend-architect
```

> **Note:** Honour all architecture decisions already in RESEARCH.md. Only deliberate on areas left unspecified.

1. **Project structure** — feature-based vs layer-based
2. **Navigation pattern** — based on REQUIREMENTS.md Navigation Structure
3. **State management** — from RESEARCH.md decision
4. **Backend integration** — from RESEARCH.md decision

### Output
- Architecture diagram
- Folder structure
- Technology decisions confirmed

---

## Phase 4: Scaffolding (45-60%)

### Project Initialization
```bash
# React Native (Expo)
npx create-expo-app@latest MyApp --template tabs

# Flutter
flutter create --org com.company my_app
```

### Core Dependencies
Install based on RESEARCH.md decisions.

### Output
- Initialized project
- Core dependencies installed

---

## Phase 5: Core Setup (60-80%)

### Load Skills
```yaml
skills:
  - rn-navigation OR flutter-navigation
  - rn-state-management OR flutter-state-management
  - networking-patterns
  - secure-storage
```

1. Navigation structure (from REQUIREMENTS.md Navigation Structure)
2. State management configuration
3. API client setup
4. Auth scaffolding

---

## Phase 6: CI/CD Setup (80-100%)

### Load Agents
```yaml
agents:
  - mobile-cicd-engineer
  - mobile-code-signing-expert
```

1. GitHub Actions workflow
2. Code signing preparation
3. Environment configuration

---

## Completion Checklist

- [ ] REQUIREMENTS.md produced
- [ ] RESEARCH.md produced
- [ ] PLAN.md with requirement-referenced tasks
- [ ] Project initialized with chosen framework
- [ ] Navigation configured
- [ ] State management set up
- [ ] API client configured
- [ ] Auth flow scaffolded
- [ ] CI/CD pipeline ready
- [ ] README with setup instructions
