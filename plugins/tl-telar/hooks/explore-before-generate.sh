#!/bin/bash
# explore-before-generate.sh — Remind to check existing architecture before generating code
# Lightweight, non-blocking hook for UserPromptSubmit

# Detect project type
if [ -f "package.json" ]; then
  if grep -q '"expo"' package.json 2>/dev/null; then
    PLATFORM="Expo (React Native)"
  elif grep -q '"react-native"' package.json 2>/dev/null; then
    PLATFORM="React Native"
  else
    PLATFORM="JavaScript/TypeScript"
  fi
elif [ -f "pubspec.yaml" ]; then
  PLATFORM="Flutter"
else
  # No project detected, skip reminder
  exit 0
fi

cat << EOF

<codebase-first-reminder>
CODEBASE-FIRST: $PLATFORM project detected.
Before generating code, check:
- Existing navigation setup and patterns
- State management library in use
- Component library and design tokens
- Test patterns and file structure
</codebase-first-reminder>

EOF
