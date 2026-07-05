---
name: "create-skill"
description: "Meta-skill for creating new skills in this plugin. Guides through complexity tiers, generates proper frontmatter, and validates the result."
source_type: "skill"
source_file: "skills/create-skill.md"
---

# create-skill

Migrated from `skills/create-skill.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Create Skill

Meta-skill for creating new skills in this plugin. Guides through complexity tiers, generates proper frontmatter, and validates the result.

## Problem

New skills are often created with missing frontmatter, inconsistent structure, or without proper validation. Patterns learned during sessions (via `learn-pattern`) need a clear promotion path to become first-class skills.

## Solution

### 1. Complexity Tiers

#### Tier 1: Simple Skill (< 200 lines)
Single markdown file in `skills/`.

```yaml
# Required frontmatter
---
id: my-new-skill
category: skill
impact: HIGH        # CRITICAL, HIGH, MEDIUM, LOW
impactDescription: One-line description of impact
tags: [tag1, tag2, tag3]
capabilities:
  - Capability 1
  - Capability 2
useWhen:
  - When to use this skill
  - Another use case
---
```

Required sections:
1. `# Title` — skill name
2. Opening paragraph — what this skill does
3. `## Problem` — what goes wrong without this skill
4. `## Solution` — the technique/pattern/approach
5. Code examples with language tags

#### Tier 2: Skill with References
Main skill file + supporting files in `references/`.

```text
skills/
  my-skill.md               # Main skill
  references/
    my-skill/
      example-config.json    # Reference data
      migration-guide.md     # Supporting docs
```

Reference files from the main skill:
```markdown
See `references/my-skill/migration-guide.md` for the full migration guide.
```

#### Tier 3: Skill with Scripts
Skill + automation script in `scripts/`.

```text
skills/
  my-skill.md
scripts/
  my-skill-helper.sh        # or .js
```

Register the script in `settings.json`:
```json
{
  "scripts": {
    "my-skill": "bash ./scripts/my-skill-helper.sh"
  }
}
```

#### Tier 4: Full Package (Agent + Skill + Command)
For comprehensive domain coverage:

```text
agents/
  my-domain-expert.md        # Agent definition
skills/
  my-skill.md                # Skill reference
commands/
  my-command.md              # Workflow command
```

### 2. Creation Process

**Step 1: Define the skill**
```markdown
- What problem does this solve?
- When should it be loaded?
- What code examples are essential?
- What's the impact level?
```

**Step 2: Choose tier**
- Does it need reference files? → Tier 2
- Does it need automation? → Tier 3
- Does it need an agent and command? → Tier 4
- Otherwise → Tier 1

**Step 3: Write the skill**
- Start with frontmatter (all required fields)
- Write Problem section
- Write Solution section with code examples
- Add Verification section
- Add References section (links to related skills/docs)

**Step 4: Validate**
```bash
node scripts/validate-skills.js
```

### 3. Promoting Learned Patterns

When a pattern is captured via `learn-pattern` and stored in `skills/learn-pattern/`:

1. Check if the pattern is useful across multiple projects (not project-specific)
2. Choose the appropriate tier
3. Create the skill file with proper structure
4. Move any relevant content from the learned pattern
5. Delete or archive the learned pattern entry
6. Validate with `validate-skills.js`

### 4. Frontmatter Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique kebab-case identifier |
| `category` | string | Yes | Always `"skill"` |
| `impact` | enum | No | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |
| `impactDescription` | string | No | One-line impact description (required if impact is set) |
| `tags` | array | Yes | Discovery keywords |
| `capabilities` | array | Yes | What this skill enables |
| `useWhen` | array | Yes | When to load this skill |

### 5. Quality Checklist

```markdown
- [ ] All required frontmatter fields present
- [ ] `id` matches filename (kebab-case)
- [ ] `category` is "skill"
- [ ] `tags` array has at least 3 items
- [ ] `capabilities` describes what the skill enables
- [ ] `useWhen` describes when to load it
- [ ] Has ## Problem section
- [ ] Has ## Solution section
- [ ] Code examples have language tags (```typescript, ```dart, etc.)
- [ ] No untagged code blocks
- [ ] Passes `node scripts/validate-skills.js`
```

## Verification

1. Run `node scripts/validate-skills.js` — no errors
2. New skill appears in validation output
3. Frontmatter parses correctly (test with the validate script)
4. Token estimate is within 50% of actual content length / 4
