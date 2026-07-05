# Skill Section Definitions

Standard sections used across all skills in the telar-framework.

## Required Sections

### Problem
- Describe the symptom developers encounter
- Include a BAD code example with comments explaining what's wrong
- Quantify the impact where possible (e.g., "causes 200ms jank on scroll")

### Solution
- Show the GOOD code example with inline comments
- Code must be production-ready, not pseudo-code
- Include TypeScript types for RN skills, Dart types for Flutter skills

### Why This Works
- Connect the root cause to the fix
- Reference framework internals when helpful
- Note platform differences (iOS vs Android)

## Recommended Sections

### Edge Cases & Pitfalls
- Platform-specific gotchas (iOS/Android behavior differences)
- Version-specific issues (RN 0.72+ vs older, Flutter 3.x vs 2.x)
- Common misconfigurations

### Verification
- Steps to confirm the fix works
- CLI commands, test patterns, or profiling steps
- Measurable criteria (e.g., "FPS should stay above 58")

### References
- Links to official documentation
- Links to relevant GitHub issues or RFCs

## Optional Sections

### Flutter Equivalent / React Native Equivalent
- Cross-reference for skills that have a counterpart in the other framework

### Advanced Patterns
- For skills that have a simple solution and an advanced optimization
- Only include if significantly different from the basic solution

## Frontmatter Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| id | Yes | string | kebab-case unique identifier |
| category | Yes | "skill" | Always "skill" |
| impact | Yes | enum | CRITICAL, HIGH, MEDIUM, or LOW |
| impactDescription | Yes | string | Quantified benefit |
| tags | Yes | string[] | Semantic tags for matching |
| capabilities | Yes | string[] | What this skill enables |
| useWhen | Yes | string[] | When to load this skill |

## Impact Levels

- **CRITICAL**: Causes crashes, data loss, or store rejection without this knowledge
- **HIGH**: Causes significant performance issues or security vulnerabilities
- **MEDIUM**: Improves code quality, maintainability, or moderate performance gains
- **LOW**: Nice-to-have optimizations or convenience patterns
