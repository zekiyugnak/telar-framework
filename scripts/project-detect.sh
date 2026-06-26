#!/bin/bash
# project-detect.sh — Detect mobile project type, framework, and dependencies
# Outputs JSON: { platform, framework, version, navigation, stateManagement, backend, typescript }

set -euo pipefail

PLATFORM="unknown"
FRAMEWORK="unknown"
VERSION=""
NAVIGATION=""
STATE_MGMT=""
BACKEND=""
TYPESCRIPT=false

# Detect React Native / Expo
if [ -f "package.json" ]; then
  PKG=$(cat package.json)

  # Platform detection
  if echo "$PKG" | grep -q '"expo"'; then
    PLATFORM="react-native"
    FRAMEWORK="expo"
    VERSION=$(echo "$PKG" | python3 -c "import json,sys; print(json.load(sys.stdin).get('dependencies',{}).get('expo',''))" 2>/dev/null || echo "")
  elif echo "$PKG" | grep -q '"react-native"'; then
    PLATFORM="react-native"
    FRAMEWORK="bare"
    VERSION=$(echo "$PKG" | python3 -c "import json,sys; print(json.load(sys.stdin).get('dependencies',{}).get('react-native',''))" 2>/dev/null || echo "")
  fi

  # TypeScript
  if echo "$PKG" | grep -q '"typescript"'; then
    TYPESCRIPT=true
  fi
  [ -f "tsconfig.json" ] && TYPESCRIPT=true

  # Navigation
  if echo "$PKG" | grep -q '"@react-navigation/native"'; then
    NAVIGATION="react-navigation"
  elif echo "$PKG" | grep -q '"expo-router"'; then
    NAVIGATION="expo-router"
  fi

  # State management
  if echo "$PKG" | grep -q '"zustand"'; then
    STATE_MGMT="zustand"
  elif echo "$PKG" | grep -q '"@reduxjs/toolkit"'; then
    STATE_MGMT="redux-toolkit"
  elif echo "$PKG" | grep -q '"mobx"'; then
    STATE_MGMT="mobx"
  elif echo "$PKG" | grep -q '"jotai"'; then
    STATE_MGMT="jotai"
  elif echo "$PKG" | grep -q '"@tanstack/react-query"'; then
    STATE_MGMT="react-query"
  fi

  # Backend
  if echo "$PKG" | grep -q '"@supabase/supabase-js"'; then
    BACKEND="supabase"
  elif echo "$PKG" | grep -q '"firebase"'; then
    BACKEND="firebase"
  elif echo "$PKG" | grep -q '"@aws-amplify"'; then
    BACKEND="amplify"
  fi

# Detect Flutter
elif [ -f "pubspec.yaml" ]; then
  PLATFORM="flutter"
  FRAMEWORK="flutter"
  TYPESCRIPT=false

  PUBSPEC=$(cat pubspec.yaml)

  # Version
  VERSION=$(echo "$PUBSPEC" | grep "flutter:" -A1 | grep "sdk:" | sed 's/.*sdk: *//' | tr -d '"' | head -1 || echo "")

  # Navigation
  if echo "$PUBSPEC" | grep -q "go_router"; then
    NAVIGATION="go_router"
  elif echo "$PUBSPEC" | grep -q "auto_route"; then
    NAVIGATION="auto_route"
  elif echo "$PUBSPEC" | grep -q "beamer"; then
    NAVIGATION="beamer"
  fi

  # State management
  if echo "$PUBSPEC" | grep -q "flutter_riverpod\|riverpod"; then
    STATE_MGMT="riverpod"
  elif echo "$PUBSPEC" | grep -q "flutter_bloc\|bloc"; then
    STATE_MGMT="bloc"
  elif echo "$PUBSPEC" | grep -q "provider"; then
    STATE_MGMT="provider"
  elif echo "$PUBSPEC" | grep -q "get:"; then
    STATE_MGMT="getx"
  fi

  # Backend
  if echo "$PUBSPEC" | grep -q "supabase_flutter"; then
    BACKEND="supabase"
  elif echo "$PUBSPEC" | grep -q "firebase_core"; then
    BACKEND="firebase"
  fi
fi

# Output JSON
cat << EOF
{
  "platform": "$PLATFORM",
  "framework": "$FRAMEWORK",
  "version": "$VERSION",
  "navigation": "$NAVIGATION",
  "stateManagement": "$STATE_MGMT",
  "backend": "$BACKEND",
  "typescript": $TYPESCRIPT
}
EOF
