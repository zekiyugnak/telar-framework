# Contributing Skills

Guidelines for writing high-quality skills for the telar-framework.

## Quick Start

1. Copy `_template.md` to a new file with a descriptive kebab-case name
2. Fill in all required frontmatter fields
3. Write Problem section with BAD code example
4. Write Solution section with GOOD code example
5. Add Why This Works explanation
6. Run `node scripts/validate-skills.js` to verify

## Writing Good Skills

### Problem Section
- Start with what the developer experiences (symptom, not cause)
- Show real code that looks correct but has issues
- Add comments like `// BAD: explanation` on problematic lines
- Quantify impact: "This causes N ms jank" or "This leaks N MB per minute"

### Solution Section
- Show the complete corrected code, not just the changed lines
- Add `// GOOD: explanation` comments on key lines
- Use TypeScript for React Native, Dart for Flutter
- Make code copy-pasteable into a real project

### Code Quality Checklist
- [ ] Code compiles/runs without modification
- [ ] Import statements are included
- [ ] Types are explicit (no `any` in TS, no `dynamic` in Dart)
- [ ] Error handling is included where appropriate
- [ ] Both iOS and Android behaviors are covered

## Skill Size Guidelines

| Type | Lines | When to use |
|------|-------|-------------|
| Focused | 100-200 | Single concept, one pattern |
| Standard | 200-400 | Multiple related patterns |
| Deep Dive | 400+ | Split into references/ subdirectory |

If a skill exceeds 400 lines, consider splitting into a main file + `references/` subdirectory.

## Reference System

For deep skills that need multiple files:

```text
skills/
├── performance/
│   ├── references/
│   │   ├── list-optimization.md
│   │   ├── startup-optimization.md
│   │   └── memory-profiling.md
│   └── COMPILED.md           # Auto-generated, do not edit
├── your-skill.md              # Simple skills stay flat
```

## Naming Conventions

- React Native skills: `rn-*.md` (e.g., `rn-navigation.md`)
- Flutter skills: `flutter-*.md` (e.g., `flutter-navigation.md`)
- Cross-platform skills: descriptive name (e.g., `offline-sync-patterns.md`)
- Supabase skills: `supabase-*.md` (e.g., `supabase-auth.md`)

## Testing Your Skill

1. **Validation**: `node scripts/validate-skills.js`
2. **Code examples**: Verify all code snippets compile/run
3. **Cross-reference**: Ensure `plugin.json` includes the skill
