---
id: agent-name
category: agent
tags: [tag1, tag2, tag3]
capabilities:
  - What this agent can do (action-oriented)
  - Another capability
useWhen:
  - Specific scenario when this agent should be invoked
  - Another triggering condition
decisionFramework:
  - condition: "Condition description"
    action: "Recommended action"
  - condition: "Another condition"
    action: "Another recommended action"
---

# Agent Title

One-line role description explaining what this agent specializes in.

## Decision Framework

Structured reasoning rules for common decisions this agent faces.

### Decision 1: [Topic]

| Condition | Recommendation | Rationale |
|-----------|---------------|-----------|
| Condition A | Use approach X | Because reason |
| Condition B | Use approach Y | Because reason |
| Condition C | Escalate to [other-agent] | Beyond this agent's scope |

### Decision 2: [Topic]

```text
IF [condition]
  THEN [action]
ELSE IF [condition]
  THEN [action]
ELSE
  [default action]
```

## Core Patterns

### Pattern 1: [Name]

```typescript
// Production-ready code example
```

### Pattern 2: [Name]

```typescript
// Production-ready code example
```

## Anti-Patterns

### 1. [Anti-Pattern Name]

**What it looks like:**
```typescript
// BAD: Code showing the anti-pattern
```

**Why it's wrong:** Explanation of the consequences.

**Instead do:**
```typescript
// GOOD: Correct approach
```

### 2. [Anti-Pattern Name]

**What it looks like:** Description of the mistake.
**Why it's wrong:** Consequence explanation.
**Instead do:** Correct approach.

### 3. [Anti-Pattern Name]

**What it looks like:** Description.
**Why it's wrong:** Consequence.
**Instead do:** Fix.

## Tool Commands

Specific CLI commands this agent should run when working:

```bash
# Diagnostic/analysis commands
command-1 --flag
command-2 --flag
```

## Escalation Paths

When to hand off to another agent:

| Situation | Hand Off To | Why |
|-----------|-------------|-----|
| [Situation] | [agent-id] | [Reason] |
| [Situation] | [agent-id] | [Reason] |

## Best Practices

- Practice 1
- Practice 2
- Practice 3

## Common Pitfalls

- Pitfall 1 and how to avoid it
- Pitfall 2 and how to avoid it
