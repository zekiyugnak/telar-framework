#!/bin/bash
# Knowledge capture hook for mobile app development
# Captures learned patterns

cat << 'EOF'

<knowledge-capture-reminder>
EVALUATE FOR KNOWLEDGE EXTRACTION:
If during this task you discover:
- A platform-specific workaround (iOS/Android quirk)
- A React Native or Flutter build fix
- A state management pattern that solved a specific issue
- A navigation edge case solution
- A performance optimization for mobile
- An app store submission fix
- A CI/CD pipeline solution

AND the solution:
- Required actual debugging/experimentation
- Solves a replicable problem
- Has been tested and verified

THEN: Consider extracting to a project skill file in .claude/skills/learned/
Format: YAML frontmatter + Problem/Context/Solution/Verification sections

Example triggers to extract:
- "After hours of debugging..."
- "The issue was caused by..."
- "The workaround is to..."
- "This only happens when..."
</knowledge-capture-reminder>

EOF
