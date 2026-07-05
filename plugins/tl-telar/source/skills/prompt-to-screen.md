---
id: prompt-to-screen
category: skill
impact: MEDIUM
impactDescription: Converts vague feature requests into precise, buildable screen specifications, reducing requirements ambiguity and rework cycles
tags: [screen-spec, requirements, wireframe, layout, navigation, platform-conventions, design, figma]
capabilities:
  - Transform rough app descriptions into structured screen specs (Mod A)
  - Read Figma designs via Figma MCP and convert to spec (Mod B)
  - Hybrid mode: combine REQUIREMENTS.md and Figma (Mod C)
  - Consult Design Assets table in REQUIREMENTS.md to auto-select mode
  - Define layout hierarchy with component trees
  - Specify state requirements and data dependencies
  - Map navigation flows between screens
  - Apply platform conventions (iOS vs Android patterns)
useWhen:
  - Building a screen that is listed in REQUIREMENTS.md
  - A stakeholder describes a feature in plain language and you need a buildable spec
  - Planning screens before starting component development
  - Translating Figma designs into developer-ready specifications
---

# Prompt to Screen

Converts screen descriptions and/or Figma designs into detailed, structured screen specifications. When REQUIREMENTS.md exists, always consult the Design Assets table first to determine which mode to use.

## Three Modes

| Mode | When to Use |
|------|------------|
| **Mod A — From description** | No Figma design available; build spec from requirements text |
| **Mod B — From Figma** | Figma design is available and status is Final or acceptable |
| **Mod C — Hybrid** | Both REQUIREMENTS.md spec and Figma design exist; cross-reference and flag differences |

---

## Figma Decision Flow (when REQUIREMENTS.md exists)

Before producing a spec, check the Design Assets table in REQUIREMENTS.md:

```text
For screen UI-x:

├── Figma reference present AND status = "Final"
│     → Use Mod B automatically (no need to ask)
│
├── Figma reference present AND status ≠ "Final" (Draft, WIP)
│     → Ask user:
│       "UI-x has a Figma design but it is not finalised (status: [Draft/WIP])."
│       Options:
│         A) "I will finalise the design first" → skip this screen for now
│         B) "Build from requirements text" → Mod A
│         C) "Use the draft design as-is" → Mod B (note: WIP)
│
├── Figma reference = "—" or "No design"
│     → Ask user:
│       "UI-x has no Figma design listed."
│       Options:
│         A) "I will create a design" → skip this screen for now
│         B) "Build from requirements text" → Mod A
│
└── Screen not in Design Assets table at all
      → Ask user:
        "UI-x is not in the Design Assets table. No requirements and no design exist for it."
        Options:
          A) "Add it to REQUIREMENTS.md first" → pause, update requirements
          B) "Describe it now" → Mod A (treat description as requirements)
```

**Rule:** Only "Final" status triggers automatic Mod B. All other situations require user confirmation.

---

## Mod A — From Description

### Input Analysis

Extract from the description or REQUIREMENTS.md UI-x section:

```typescript
interface ScreenPromptAnalysis {
  rawDescription: string;
  purpose: string;
  primaryAction: string;
  dataRequirements: string[];
  interactions: string[];
  navigationContext: { from: string[]; to: string[] };
}
```

### Screen Specification Template

```markdown
# Screen: [Screen Name] (UI-x)

## Requirements Reference
**REQUIREMENTS.md:** UI-x, F-y, F-z
**Figma:** [link or "None"]

## Purpose
[One sentence]

## Layout Hierarchy
```
SafeAreaView
  +-- Header
  |     +-- BackButton
  |     +-- Title: "[Screen Name]"
  +-- ScrollView
  |     +-- Section: [Section]
  |           +-- [Component]: [description]
  +-- BottomCTA
        +-- Button: "[Action]"
```markdown

## Components
| Component | Type | Props | State |
|-----------|------|-------|-------|
| [Name] | [Type] | [props] | [local/server/global] |

## State Requirements
- **Local:** form values, validation errors
- **Server:** [data from backend]
- **Global:** [auth, theme]

## Data Dependencies
- [API call or RPC]

## Navigation
- **Entry points:** [where user comes from]
- **Exit points:** [where user goes]
- **Deep link:** [pattern]

## Platform Conventions
- iOS: [pattern]
- Android: [pattern]

## Accessibility
- Screen reader announcement on load: "[Screen name] screen"
- Focus order: [component list]

## States
- **Loading:** [skeleton or spinner]
- **Error:** [error UI]
- **Empty:** [empty state]
- **Success:** [main content]
```

---

## Mod B — From Figma

Requires Figma MCP to be connected.

### Steps

1. **Get Figma node ID** from Design Assets table in REQUIREMENTS.md
2. **Fetch design context** via Figma MCP: `get_design_context(nodeId)`
3. **Extract layout**: read component tree, frame names, auto-layout structure
4. **Map to spec template**: translate Figma layers to Layout Hierarchy and Components table
5. **Cross-reference requirements**: check that Figma design covers all F-x for this screen
6. **Flag discrepancies**: if Figma design omits a required F-x element, note it

### Output additions for Mod B

```markdown
## Figma Source
**Node ID:** [id]
**Last fetched:** [date]
**Design status:** Final | Draft | WIP

## Figma ↔ Requirements Discrepancies
| Requirement | In Figma? | Notes |
|-------------|-----------|-------|
| F-7 share button | ❌ Missing | Figma v2 does not show share button — build from spec |
| F-3 notification badge | ✅ Present | Tab bar icon has badge indicator |
```

---

## Mod C — Hybrid

Use when both REQUIREMENTS.md spec and a Figma design exist:

1. Run Mod A (extract spec from REQUIREMENTS.md)
2. Run Mod B (extract spec from Figma)
3. Merge: use Figma for layout/visual; use REQUIREMENTS.md for business rules and states
4. Produce a single unified spec with Figma ↔ Requirements Discrepancies section

---

## Platform Convention Mapping

```typescript
const platformConventions = {
  modal: { ios: 'presentAsSheet', android: 'bottomSheet' },
  picker: { ios: 'wheelPicker', android: 'dropdownMenu' },
  destructiveAction: { ios: 'actionSheet', android: 'alertDialog' },
  search: { ios: 'searchBar', android: 'searchView' },
  datePicker: { ios: 'inlineCalendar', android: 'calendarDialog' },
  list: { ios: 'groupedInsetList', android: 'flatList' },
};
```

---

## Verification

1. Design Assets table in REQUIREMENTS.md was consulted before selecting mode
2. Mode selection followed the Figma Decision Flow (user confirmed for non-Final designs)
3. Every element in the layout hierarchy maps to a component in the components table
4. Both iOS and Android conventions documented for differing patterns
5. All four states handled: loading, error, empty, success
6. In Mod B/C: Figma ↔ Requirements Discrepancies section present

## References

- Input: `REQUIREMENTS.md` Design Assets table, Figma MCP (`get_design_context`)
- Used by: `agents/mobile-screen-builder.md`
- Apple HIG: https://developer.apple.com/design/human-interface-guidelines/app-architecture
- Material Design: https://m3.material.io/foundations/interaction/navigation
