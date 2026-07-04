# Sample Good Plan (Test Fixture)

> This fixture is intentionally well-formed and references real files
> in THIS plugin repo so rubric A1 (path existence) is honestly
> testable. The Plan Review Gate MUST return PASS with at most
> advisories.

**Goal:** Add a new validation script that checks `CHANGELOG.md` formatting.

**Original user request:** "Add a script that validates CHANGELOG.md
formatting and wire it into the existing validate-skills.js companion
script set."

## Tasks

### Task 1: Create scripts/validate-changelog.js

**Files:** Create `scripts/validate-changelog.js`.

**DoD:**
- [ ] Script reads `CHANGELOG.md` from repo root.
- [ ] Returns exit 0 if the file follows Keep a Changelog v1.1.0 format.
- [ ] Returns exit 1 with an error message identifying the line if not.
- [ ] If `CHANGELOG.md` does not exist, exits 0 with a "no changelog yet" notice (does not fail until one is created).

```js
#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const CHANGELOG = path.join(__dirname, '..', 'CHANGELOG.md');
if (!fs.existsSync(CHANGELOG)) {
  console.log('No CHANGELOG.md yet — skipping.');
  process.exit(0);
}
const content = fs.readFileSync(CHANGELOG, 'utf8');
const lines = content.split('\n');
let errors = 0;
if (!lines[0].startsWith('# Changelog')) {
  console.error('Line 1: missing "# Changelog" title');
  errors++;
}
const hasUnreleased = lines.some(l => /^##\s+\[Unreleased\]/.test(l));
if (!hasUnreleased) {
  console.error('Missing "## [Unreleased]" section');
  errors++;
}
process.exit(errors > 0 ? 1 : 0);
```

### Task 2: Reference the validator from CLAUDE.md scripts table

**Files:** Modify `CLAUDE.md` (verified to exist at repo root). Find the Scripts table and add this row at the end:

```markdown
| `scripts/validate-changelog.js` | Validate CHANGELOG.md follows Keep a Changelog v1.1.0 |
```

**DoD:**
- [ ] CLAUDE.md Scripts table contains the new row.
- [ ] No other CLAUDE.md content changed.

### Task 3: Smoke test

**Files:** none new (manual run).

```bash
node scripts/validate-changelog.js
echo "Exit code: $?"
```

**DoD:**
- [ ] Script runs (does not crash with syntax error).
- [ ] Exit code is 0 (file present and valid, OR file absent — both are OK per Task 1 DoD).

## Expected reviewer findings

| Reviewer | Verdict | Notes |
|---|---|---|
| Feasibility | PASS | All paths (`scripts/validate-changelog.js` to be created, `CLAUDE.md` exists, `CHANGELOG.md` checked at runtime) are valid. No fictional dependencies. No Windows paths. Test step has actual command. |
| Completeness | PASS | Each task has DoD; new file has code block; CLAUDE.md row provided verbatim; smoke test has a command. |
| Scope-Alignment | PASS | Plan is exactly the user's request: add a CHANGELOG validator and reference it. No premature abstractions, no unrelated refactors. |

Advisories: none expected (this plan touches no UI, no state, no release config). M4 (missing thresholds) does not apply because plan does not reference thresholds.
