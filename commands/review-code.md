---
id: review-code
name: Review Code
description: Mobile-specific code review with two-stage review gates, platform conventions, and priority-ranked findings
category: command
usage: /tl-telar:review-code [file or directory]
example: /tl-telar:review-code src/features/auth
phases:
  - name: Spec Compliance
    progress: 0-15%
  - name: Architecture Review
    progress: 15-35%
  - name: Pattern Analysis
    progress: 35-50%
  - name: Performance Review
    progress: 50-65%
  - name: Security Review
    progress: 65-80%
  - name: Accessibility Review
    progress: 80-100%
---

# Code Review

Comprehensive mobile-specific code review with two-stage review gates.

## Phase 0: Specification Compliance (0-15%)

### Load Skills
```yaml
skills:
  - review-gates    # Two-stage review gates
rules:
  - platform-conventions    # HIG/Material traceability
```

### Stage 1: Spec Compliance
If PLAN.md exists:
- Check each task's acceptance criteria against implementation
- Flag unmet criteria
- Verify PROGRESS.md is up to date

If no PLAN.md:
- Skip this phase, proceed to architecture review

### Verification Evidence
Before concluding any phase, require fresh verification:
```yaml
skills:
  - verification-before-completion
```
- All "pass" verdicts must reference fresh test runs or simulator verification
- Do not accept stale evidence from before the latest changes

### Output
- Spec compliance status (pass/fail per criterion)

## Phase 1: Architecture Review (15-35%)

### Load Agents
```yaml
agents:
  - react-native-expert OR flutter-expert
  - mobile-navigation-architect
```

### Review Areas
1. **Project structure**
   - Feature organization
   - Module boundaries
   - Import structure

2. **Component architecture**
   - Component responsibilities
   - Prop drilling depth
   - State colocation

3. **Navigation structure**
   - Route organization
   - Deep linking coverage
   - Navigation state management

### Checklist
```markdown
- [ ] Clear separation of concerns
- [ ] Consistent folder structure
- [ ] Appropriate module boundaries
- [ ] No circular dependencies
```

### Output
- Architecture issues list
- Recommendations

## Phase 2: Pattern Analysis (20-40%)

### Load Agents
```yaml
agents:
  - mobile-state-management
```

### Review Areas
1. **State management**
   - Appropriate state location
   - Server vs client state
   - State update patterns

2. **Data fetching**
   - Loading states
   - Error handling
   - Caching strategy

3. **Component patterns**
   - Presentational vs container
   - Hooks usage
   - Render optimization

### Anti-Patterns to Flag
```typescript
// ❌ State in wrong place
const [globalData, setGlobalData] = useState() // Should be global

// ❌ Missing error handling
const data = await fetch(url) // No try/catch

// ❌ Prop drilling
<A><B><C><D prop={value} /></C></B></A>
```

### Output
- Pattern issues list
- Refactoring suggestions

## Phase 3: Performance Review (40-60%)

### Load Agents
```yaml
agents:
  - mobile-performance-optimizer
```

### Review Areas
1. **Render performance**
   - Unnecessary re-renders
   - Missing memoization
   - Large component trees

2. **List performance**
   - FlatList/ListView optimization
   - Key extraction
   - Item memoization

3. **Bundle size**
   - Large imports
   - Unused dependencies
   - Code splitting opportunities

### Performance Flags
```typescript
// ❌ Re-render on every render
<Item style={{ margin: 10 }} />

// ❌ Missing keyExtractor
<FlatList data={items} />

// ❌ Full library import
import _ from 'lodash'
```

### Output
- Performance issues list
- Optimization opportunities

## Phase 4: Security Review (60-80%)

### Load Agents
```yaml
agents:
  - mobile-security-specialist
```

### Review Areas
1. **Data storage**
   - Sensitive data in secure storage
   - No secrets in code
   - Proper encryption

2. **Network security**
   - HTTPS only
   - Certificate pinning
   - Auth token handling

3. **Input validation**
   - User input sanitization
   - API response validation

### Security Flags
```typescript
// ❌ Sensitive data in AsyncStorage
await AsyncStorage.setItem('token', authToken)

// ❌ Hardcoded secrets
const API_KEY = 'sk-xxx'

// ❌ Missing validation
const data = await response.json() // No validation
```

### Output
- Security issues list
- Severity ratings
- Remediation steps

## Phase 5: Accessibility Review (80-100%)

### Load Agents
```yaml
agents:
  - mobile-accessibility-expert
```

### Review Areas
1. **Screen reader support**
   - Accessibility labels
   - Semantic elements
   - Focus order

2. **Touch targets**
   - Minimum 44x44 points
   - Adequate spacing

3. **Visual accessibility**
   - Color contrast
   - Text scaling
   - Motion sensitivity

### Accessibility Flags
```typescript
// ❌ Missing accessibility label
<TouchableOpacity onPress={onPress}>
  <Icon name="settings" />
</TouchableOpacity>

// ❌ Small touch target
<Pressable style={{ padding: 4 }} />
```

### Output
- Accessibility issues list
- WCAG compliance status
- Fixes required

## Final Report

### Summary
```markdown
| Category | Issues | Critical | High | Medium | Low |
|----------|--------|----------|------|--------|-----|
| Architecture | 3 | 0 | 1 | 2 | 0 |
| Patterns | 5 | 0 | 2 | 2 | 1 |
| Performance | 4 | 1 | 1 | 2 | 0 |
| Security | 2 | 1 | 1 | 0 | 0 |
| Accessibility | 6 | 0 | 2 | 3 | 1 |
```

### Stage 2: Code Quality Summary
```markdown
- [ ] Follows project patterns (codebase-first)
- [ ] Platform conventions respected (HIG/Material)
- [ ] Touch targets >= 44x44 (iOS) / 48x48 (Android)
- [ ] Deep link handling correct
- [ ] Error states handled
- [ ] Tests included
- [ ] No duplication (textual or semantic — same job, different code) whose sites change together for the same reason; existing shared units reused, not re-implemented
- [ ] No bloat / speculative abstraction (simplicity-first); design patterns applied only where they earn complexity
- [ ] NOT flagged: coincidental similarity with different responsibilities (wrong abstraction), dogmatic tiny-function/length gates
```

> Apply the full rule catalog from `resources/rubrics/orchestration/maintainability-design-adversarial-rubric.md` (D-DUP / D-REUSE / D-BLOAT / D-SMELL / D-SOLID / D-PATTERN / D-CLEAN). Genuine duplication/bloat → P1 (blocks merge); reuse/refactor suggestions → P3 (advisory). Honor the Metz "change together for the same reason" guardrail.

### Action Items
- P1 — Fix immediately (blocks merge)
- P2 — Fix before merge (quality issues)
- P3 — Track for later (improvements)

### References
- `rules/platform-conventions.md` for HIG/Material compliance
- `skills/review-gates.md` for two-stage review process
- `resources/rubrics/orchestration/maintainability-design-adversarial-rubric.md` for the senior maintainability/design rule catalog (duplication, reuse, bloat, smells, SOLID)
- `skills/clean-code.md` for the implementer-side authoring contract
