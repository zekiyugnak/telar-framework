#!/bin/bash
# sim-control.sh — Unified simulator/emulator automation
# Usage: sim-control.sh <command> [options]
# Commands: list, boot, screenshot, install, launch, log, status, deeplink

set -euo pipefail

VERBOSE=false
JSON_OUTPUT=false

usage() {
  cat << 'EOF'
Usage: sim-control.sh <command> [options]

Commands:
  list                          List available simulators/emulators
  boot [device-name|id]         Boot a simulator/emulator
  screenshot [output-path]      Take screenshot of booted device
  install <app-path>            Install app on booted device
  launch <bundle-id>            Launch app by bundle ID
  log [--lines N]               Show device logs (default: 50 lines)
  status                        Show status of running devices
  deeplink <url>                Open deep link on booted device

Options:
  --verbose                     Show detailed output
  --json                        Output in JSON format
  --platform ios|android        Force platform (auto-detected by default)

EOF
  exit 1
}

# Parse global options
PLATFORM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --json) JSON_OUTPUT=true; shift ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    *) break ;;
  esac
done

COMMAND="${1:-}"
shift || true

# Auto-detect platform
detect_platform() {
  if [[ -n "$PLATFORM" ]]; then
    echo "$PLATFORM"
    return
  fi

  local has_ios=false
  local has_android=false

  command -v xcrun &>/dev/null && has_ios=true
  command -v adb &>/dev/null && has_android=true

  if $has_ios && $has_android; then
    # Check which has a booted device
    if xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
      echo "ios"
    elif adb devices 2>/dev/null | grep -q "device$"; then
      echo "android"
    else
      echo "ios"  # Default to iOS on macOS
    fi
  elif $has_ios; then
    echo "ios"
  elif $has_android; then
    echo "android"
  else
    echo "none"
  fi
}

# --- iOS Functions ---

ios_list() {
  if $JSON_OUTPUT; then
    xcrun simctl list devices available -j 2>/dev/null
  elif $VERBOSE; then
    xcrun simctl list devices available 2>/dev/null
  else
    echo "iOS Simulators:"
    xcrun simctl list devices available 2>/dev/null | grep -E "(Booted|Shutdown)" | head -10
    local total
    total=$(xcrun simctl list devices available 2>/dev/null | grep -cE "(Booted|Shutdown)" || true)
    [[ $total -gt 10 ]] && echo "  ... and $((total - 10)) more (use --verbose)"
  fi
}

ios_boot() {
  local device="${1:-}"
  if [[ -z "$device" ]]; then
    # Boot the latest iPhone
    device=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime in sorted(data.get('devices', {}).keys(), reverse=True):
  if 'iOS' in runtime:
    for d in data['devices'][runtime]:
      if 'iPhone' in d['name'] and 'Pro' in d['name']:
        print(d['udid']); sys.exit(0)
    for d in data['devices'][runtime]:
      if 'iPhone' in d['name']:
        print(d['udid']); sys.exit(0)
" 2>/dev/null || true)
    [[ -z "$device" ]] && { echo "No iPhone simulator found"; exit 1; }
  fi
  xcrun simctl boot "$device" 2>/dev/null || true
  open -a Simulator 2>/dev/null || true
  echo "Booted iOS simulator: $device"
}

ios_screenshot() {
  local output="${1:-screenshot-$(date +%Y%m%d-%H%M%S).png}"
  xcrun simctl io booted screenshot "$output" 2>/dev/null
  echo "Screenshot saved: $output"
}

ios_install() {
  local app_path="$1"
  xcrun simctl install booted "$app_path" 2>/dev/null
  echo "Installed: $app_path"
}

ios_launch() {
  local bundle_id="$1"
  xcrun simctl launch booted "$bundle_id" 2>/dev/null
  echo "Launched: $bundle_id"
}

ios_log() {
  local lines="${1:-50}"
  xcrun simctl spawn booted log stream --level info --style compact 2>/dev/null | head -n "$lines"
}

ios_status() {
  if $JSON_OUTPUT; then
    xcrun simctl list devices booted -j 2>/dev/null
  else
    echo "Booted iOS Simulators:"
    xcrun simctl list devices booted 2>/dev/null | grep "Booted" || echo "  None"
  fi
}

ios_deeplink() {
  local url="$1"
  xcrun simctl openurl booted "$url" 2>/dev/null
  echo "Opened: $url"
}

# --- Android Functions ---

android_list() {
  if $JSON_OUTPUT; then
    emulator -list-avds 2>/dev/null | python3 -c "
import json, sys
avds = [line.strip() for line in sys.stdin if line.strip()]
print(json.dumps({'avds': avds}))" 2>/dev/null
  elif $VERBOSE; then
    emulator -list-avds 2>/dev/null
    echo ""
    adb devices -l 2>/dev/null
  else
    echo "Android Emulators:"
    emulator -list-avds 2>/dev/null | head -5
    local running
    running=$(adb devices 2>/dev/null | grep -c "device$" || true)
    echo "Running: $running device(s)"
  fi
}

android_boot() {
  local device="${1:-}"
  if [[ -z "$device" ]]; then
    device=$(emulator -list-avds 2>/dev/null | head -1)
    [[ -z "$device" ]] && { echo "No Android emulator found"; exit 1; }
  fi
  emulator -avd "$device" -no-snapshot-load &>/dev/null &
  echo "Booting Android emulator: $device"
}

android_screenshot() {
  local output="${1:-screenshot-$(date +%Y%m%d-%H%M%S).png}"
  adb exec-out screencap -p > "$output" 2>/dev/null
  echo "Screenshot saved: $output"
}

android_install() {
  local app_path="$1"
  adb install -r "$app_path" 2>/dev/null
  echo "Installed: $app_path"
}

android_launch() {
  local package="$1"
  adb shell monkey -p "$package" -c android.intent.category.LAUNCHER 1 2>/dev/null
  echo "Launched: $package"
}

android_log() {
  local lines="${1:-50}"
  adb logcat -d -t "$lines" 2>/dev/null
}

android_status() {
  if $JSON_OUTPUT; then
    adb devices -l 2>/dev/null | tail -n +2 | python3 -c "
import json, sys
devices = []
for line in sys.stdin:
  parts = line.strip().split()
  if len(parts) >= 2:
    devices.append({'id': parts[0], 'status': parts[1]})
print(json.dumps({'devices': devices}))" 2>/dev/null
  else
    echo "Connected Android Devices:"
    adb devices -l 2>/dev/null | tail -n +2 | grep -v "^$" || echo "  None"
  fi
}

android_deeplink() {
  local url="$1"
  adb shell am start -a android.intent.action.VIEW -d "$url" 2>/dev/null
  echo "Opened: $url"
}

# --- Main ---

[[ -z "$COMMAND" ]] && usage

DETECTED_PLATFORM=$(detect_platform)

case "$COMMAND" in
  list)
    if [[ "$DETECTED_PLATFORM" == "ios" ]] || [[ "$DETECTED_PLATFORM" == "none" && "$(uname)" == "Darwin" ]]; then
      ios_list
    fi
    if command -v adb &>/dev/null || command -v emulator &>/dev/null; then
      [[ "$DETECTED_PLATFORM" == "ios" ]] && echo ""
      android_list
    fi
    ;;
  boot)       [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_boot "$@" || android_boot "$@" ;;
  screenshot) [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_screenshot "$@" || android_screenshot "$@" ;;
  install)    [[ -z "${1:-}" ]] && { echo "Usage: sim-control.sh install <app-path>"; exit 1; }
              [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_install "$@" || android_install "$@" ;;
  launch)     [[ -z "${1:-}" ]] && { echo "Usage: sim-control.sh launch <bundle-id>"; exit 1; }
              [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_launch "$@" || android_launch "$@" ;;
  log)
    LINES=50
    [[ "${1:-}" == "--lines" ]] && LINES="${2:-50}"
    [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_log "$LINES" || android_log "$LINES" ;;
  status)     [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_status || android_status ;;
  deeplink)   [[ -z "${1:-}" ]] && { echo "Usage: sim-control.sh deeplink <url>"; exit 1; }
              [[ "$DETECTED_PLATFORM" == "ios" ]] && ios_deeplink "$@" || android_deeplink "$@" ;;
  *) echo "Unknown command: $COMMAND"; usage ;;
esac
