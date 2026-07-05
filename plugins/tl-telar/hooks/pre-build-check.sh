#!/bin/bash
# Pre-build validation hook for mobile app development
# Registered as PreToolUse(Bash). Receives Claude Code hook JSON on stdin and
# short-circuits for any Bash command that is not a mobile build invocation.

set -e

# Read the hook event payload from stdin (Claude Code PreToolUse contract).
# If stdin is empty (manual invocation), fall through and run all checks.
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat)
fi

# Extract the command being run, if any. Tolerant of missing jq.
TOOL_COMMAND=""
if [ -n "$PAYLOAD" ]; then
    if command -v jq >/dev/null 2>&1; then
        TOOL_COMMAND=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""' 2>/dev/null)
    else
        # Best-effort grep fallback when jq is unavailable.
        TOOL_COMMAND=$(printf '%s' "$PAYLOAD" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\(.*\)"/\1/')
    fi
fi

# Only run the full check for recognised mobile build commands.
# Non-build Bash calls exit silently to avoid noise on every shell tool use.
BUILD_PATTERN='xcodebuild|gradlew|gradle (assemble|bundle|build)|flutter (build|run)|eas (build|submit)|fastlane (build|beta|release)|pod install|npx react-native run-(ios|android)|expo (build|export|prebuild)'
if [ -n "$TOOL_COMMAND" ] && ! printf '%s' "$TOOL_COMMAND" | grep -Eq "$BUILD_PATTERN"; then
    exit 0
fi

echo "📱 Mobile App Pre-Build Check"
echo "=============================="

ISSUES=()
WARNINGS=()

# Detect platform
if [ -f "pubspec.yaml" ]; then
    PLATFORM="flutter"
elif [ -f "package.json" ] && grep -q "react-native" package.json 2>/dev/null; then
    PLATFORM="react-native"
else
    PLATFORM="unknown"
fi

echo "Detected platform: $PLATFORM"
echo ""

# 1. Check for uncommitted changes
if git status --porcelain 2>/dev/null | grep -q .; then
    WARNINGS+=("Uncommitted changes detected")
fi

# 2. Platform-specific checks
if [ "$PLATFORM" = "flutter" ]; then
    # Check Flutter version
    if command -v flutter >/dev/null 2>&1; then
        FLUTTER_VERSION=$(flutter --version | head -1)
        echo "Flutter: $FLUTTER_VERSION"
    fi

    # Check for outdated dependencies
    if flutter pub outdated 2>/dev/null | grep -q "dependencies are out of date"; then
        WARNINGS+=("Some dependencies are outdated - run 'flutter pub upgrade'")
    fi

    # Check for iOS Podfile.lock
    if [ -d "ios" ] && [ ! -f "ios/Podfile.lock" ]; then
        ISSUES+=("iOS Podfile.lock missing - run 'cd ios && pod install'")
    fi

elif [ "$PLATFORM" = "react-native" ]; then
    # Check Node version
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node --version)
        echo "Node: $NODE_VERSION"
    fi

    # Check for node_modules
    if [ ! -d "node_modules" ]; then
        ISSUES+=("node_modules missing - run 'npm install' or 'yarn'")
    fi

    # Check for iOS pods
    if [ -d "ios" ] && [ ! -f "ios/Pods/Manifest.lock" ]; then
        WARNINGS+=("iOS pods may need install - run 'cd ios && pod install'")
    fi
fi

# 3. Check for debug configurations in release files
if grep -r "localhost\|127\.0\.0\.1" --include="*.dart" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules | grep -v ".git" | head -1 > /dev/null; then
    WARNINGS+=("Localhost URLs found - verify API endpoints for production")
fi

# 4. Check for sensitive files
SENSITIVE_FILES=(".env" ".env.local" "google-services.json" "GoogleService-Info.plist")
for file in "${SENSITIVE_FILES[@]}"; do
    if git ls-files --error-unmatch "$file" 2>/dev/null; then
        ISSUES+=("$file is tracked by git - should be in .gitignore")
    fi
done

# 5. Check Android signing (release builds)
if [ -d "android" ]; then
    if [ ! -f "android/app/upload-keystore.jks" ] && [ ! -f "android/key.properties" ]; then
        WARNINGS+=("Android release signing not configured")
    fi
fi

# Output results
echo ""
if [ ${#ISSUES[@]} -gt 0 ]; then
    echo "❌ Issues (should fix before build):"
    for issue in "${ISSUES[@]}"; do
        echo "   • $issue"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "⚠️  Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "   • $warning"
    done
fi

if [ ${#ISSUES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "✅ All pre-build checks passed"
fi

# Exit with error only for critical issues
if [ ${#ISSUES[@]} -gt 0 ]; then
    exit 1
fi

exit 0
