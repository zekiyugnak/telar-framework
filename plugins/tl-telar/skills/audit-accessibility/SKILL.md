---
name: "audit-accessibility"
description: "Comprehensive accessibility audit with automated scanning, semantic analysis, and priority-ranked findings"
source_type: "command"
source_file: "commands/audit-accessibility.md"
---

# audit-accessibility

Migrated from `commands/audit-accessibility.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- In Codex, this skill is the replacement for the Claude slash command `/tl-telar:audit-accessibility`; invoke it as `$audit-accessibility` or through `@tl-telar`.
- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.
- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.


# Accessibility Audit

Active accessibility audit with automated code scanning, semantic analysis, and priority-ranked findings with remediation code.

## Phase 1: Automated Scan (0-30%)

### Load Agents
```yaml
agents:
  - mobile-accessibility-expert
  - react-native-expert OR flutter-expert
```

### Code Scan Checks

Scan all UI files for automated detections:

#### Missing Accessibility Labels
```typescript
// React Native — flag these patterns:
<TouchableOpacity onPress={fn}>     // Missing accessibilityLabel
  <Icon name="settings" />
</TouchableOpacity>

<Image source={avatar} />            // Missing accessibilityLabel

// Flutter — flag these patterns:
IconButton(onPressed: fn, icon: Icon(Icons.settings))  // Missing tooltip/semanticLabel
Image.network(url)                                       // Missing semanticsLabel
```

#### Small Touch Targets
```typescript
// Flag any interactive element with dimensions < 44x44 points (iOS) / 48x48 dp (Android)
<Pressable style={{ width: 24, height: 24 }} />          // P1: too small
<Pressable style={{ padding: 4 }} />                      // P1: likely too small

// Flutter
SizedBox(width: 24, height: 24, child: GestureDetector()) // P1: too small
```

#### Color Contrast
- Check hardcoded color combinations against WCAG AA (4.5:1 for text, 3:1 for large text)
- Flag colors close to background colors
- Check dark mode color definitions

#### Missing Semantic Roles
```typescript
// React Native
<View onTouchEnd={fn} />              // Should be Pressable with accessibilityRole
<Text onPress={fn}>Click me</Text>    // Should have accessibilityRole="button"

// Flutter
GestureDetector(child: Container())   // Should use semantic widget (ElevatedButton, etc.)
```

### Output: Automated Findings List
Each finding:
- **ID**: A-001, A-002, etc.
- **Priority**: P1 / P2 / P3
- **Category**: Labels, Touch Targets, Contrast, Semantics
- **File**: path:line
- **Description**: what's wrong
- **Confidence**: High / Medium (for heuristic checks)

## Phase 2: Semantic Analysis (30-60%)

### Navigation Order
- Trace the accessibility tree order for each screen
- Flag illogical tab order (e.g., button before its label)
- Check that modals/sheets trap focus correctly

### Heading Hierarchy
```typescript
// Flag missing or skipped heading levels
// Screen should have: H1 (title) > H2 (sections) > H3 (subsections)
<Text accessibilityRole="header">Section</Text>  // What level?

// Flutter
Semantics(header: true, child: Text('Section'))   // Check hierarchy
```

### Dynamic Content Announcements
- Check that loading states announce to screen readers
- Check that error messages are announced (assertive)
- Check that list updates announce count changes
- Check that navigation transitions announce new screen

```typescript
// React Native — check for AccessibilityInfo.announceForAccessibility
// or accessibilityLiveRegion="polite" / "assertive"

// Flutter — check for SemanticsService.announce or livRegion
```

### Form Accessibility
- Labels associated with inputs
- Error messages linked to fields
- Required field indicators accessible
- Keyboard type matches input (email, phone, etc.)

### Output: Semantic Findings List (same format as Phase 1)

## Phase 3: Manual Verification Checklist (60-85%)

Generate a platform-specific manual testing checklist:

### VoiceOver Testing (iOS)
```markdown
- [ ] Enable VoiceOver: Settings > Accessibility > VoiceOver
- [ ] Navigate through each screen using swipe left/right
- [ ] Verify all interactive elements are reachable
- [ ] Verify all elements have meaningful labels (not "button" or "image")
- [ ] Check custom gestures have alternatives
- [ ] Test with rotor (headings, links, form fields)
- [ ] Verify modal/sheet focus trapping
- [ ] Test landscape orientation
- [ ] Test with increased text size (Settings > Display > Text Size)
```

### TalkBack Testing (Android)
```markdown
- [ ] Enable TalkBack: Settings > Accessibility > TalkBack
- [ ] Navigate through each screen using swipe
- [ ] Verify focus order is logical
- [ ] Test custom actions (swipe actions, long press)
- [ ] Check touch exploration works for all targets
- [ ] Verify announcements for state changes
- [ ] Test with font size 200%
- [ ] Test with display size "Largest"
```

### Cross-Platform Checks
```markdown
- [ ] All images have alt text or are decorative (hidden from a11y tree)
- [ ] Videos have captions or transcripts
- [ ] No information conveyed by color alone
- [ ] Animations respect reduced motion preference
- [ ] Timeout warnings give enough time to respond
- [ ] Error recovery doesn't require precise gestures
```

## Phase 4: Report (85-100%)

### Priority Definitions

| Priority | Meaning | Action |
|----------|---------|--------|
| **P1** | Blocks release — prevents screen reader users from completing core tasks | Fix before release |
| **P2** | Should fix — degrades experience for assistive tech users | Fix within current sprint |
| **P3** | Improvement — enhances a11y but not a blocker | Track in backlog |

### Report Format

```markdown
# Accessibility Audit Report

## Summary
| Priority | Count | Category Breakdown |
|----------|-------|--------------------|
| P1       | [N]   | Labels: X, Touch: Y, Semantics: Z |
| P2       | [N]   | Contrast: X, Navigation: Y |
| P3       | [N]   | Announcements: X, Forms: Y |

## P1 Findings (Fix Before Release)

### A-001: Missing accessibility label on checkout button
- **File:** `src/screens/CartScreen.tsx:47`
- **Confidence:** High
- **Description:** Submit button has no accessibilityLabel; VoiceOver reads "button"
- **Remediation:**
```tsx
// Before
<TouchableOpacity onPress={handleCheckout}>
  <Icon name="cart" size={24} />
</TouchableOpacity>

// After
<TouchableOpacity
  onPress={handleCheckout}
  accessibilityLabel="Proceed to checkout"
  accessibilityRole="button"
>
  <Icon name="cart" size={24} />
</TouchableOpacity>
```

## P2 Findings (Fix This Sprint)
[Same format]

## P3 Findings (Backlog)
[Same format]

## Manual Testing Results
[Checklist completion status from Phase 3]

## WCAG 2.1 AA Compliance Summary
| Criterion | Status | Notes |
|-----------|--------|-------|
| 1.1.1 Non-text Content | Pass/Fail | |
| 1.3.1 Info and Relationships | Pass/Fail | |
| 1.4.3 Contrast (Minimum) | Pass/Fail | |
| 2.1.1 Keyboard | Pass/Fail | |
| 2.4.3 Focus Order | Pass/Fail | |
| 4.1.2 Name, Role, Value | Pass/Fail | |
```

## Completion Checklist

- [ ] All UI files scanned for accessibility issues
- [ ] Semantic analysis of navigation order complete
- [ ] Dynamic announcements checked
- [ ] Manual verification checklist generated
- [ ] All findings have priority (P1/P2/P3) and remediation code
- [ ] WCAG 2.1 AA compliance summary produced
