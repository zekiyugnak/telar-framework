---
name: "app-demo-video"
description: "Automate screenshot capture, screen recording, and demo flow scripting for mobile app presentations, store listings, and documentation."
source_type: "skill"
source_file: "skills/app-demo-video.md"
---

# app-demo-video

Migrated from `skills/app-demo-video.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# App Demo Video

Automate screenshot capture, screen recording, and demo flow scripting for mobile app presentations, store listings, and documentation.

## Problem

Generating app store screenshots, demo videos, and documentation images is tedious and error-prone when done manually. Developers take screenshots by hand, forget to capture all required device sizes, miss dark mode variants, and cannot reproduce the exact state shown in a previous screenshot. Store guidelines require specific device sizes and counts, making manual capture unsustainable.

## Solution

### 1. iOS Simulator Screenshot Automation

```bash
#!/bin/bash
# scripts/capture-ios-screenshots.sh

SCREENSHOT_DIR="./screenshots/ios"
mkdir -p "$SCREENSHOT_DIR"

# List available simulators
xcrun simctl list devices available

# Boot specific simulators for required App Store sizes
DEVICES=(
  "iPhone 15 Pro Max"    # 6.7" display (required)
  "iPhone 15 Pro"        # 6.1" display (required)
  "iPad Pro (12.9-inch)" # 12.9" iPad (if universal app)
)

for DEVICE in "${DEVICES[@]}"; do
  DEVICE_SAFE=$(echo "$DEVICE" | tr ' ' '_' | tr -d '()')
  UDID=$(xcrun simctl list devices available | grep "$DEVICE" | head -1 | grep -oE '[0-9A-F-]{36}')

  if [ -z "$UDID" ]; then
    echo "Device not found: $DEVICE"
    continue
  fi

  echo "Capturing on $DEVICE ($UDID)..."

  # Boot the simulator
  xcrun simctl boot "$UDID" 2>/dev/null

  # Set appearance mode
  xcrun simctl ui "$UDID" appearance light

  # Wait for app to launch
  sleep 3

  # Capture screenshot
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/${DEVICE_SAFE}_light.png"

  # Switch to dark mode and capture
  xcrun simctl ui "$UDID" appearance dark
  sleep 1
  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/${DEVICE_SAFE}_dark.png"

  # Set status bar to clean state (9:41, full battery, full signal)
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 \
    --wifiBars 3

  xcrun simctl io "$UDID" screenshot "$SCREENSHOT_DIR/${DEVICE_SAFE}_store.png"

  # Reset status bar
  xcrun simctl status_bar "$UDID" clear
done
```

### 2. Android Emulator Screenshot Automation

```bash
#!/bin/bash
# scripts/capture-android-screenshots.sh

SCREENSHOT_DIR="./screenshots/android"
mkdir -p "$SCREENSHOT_DIR"

# Required Google Play device sizes
# Phone: 16:9 and 20:9 aspect ratios
# Tablet: 7" and 10" (if applicable)

# Capture screenshot
adb exec-out screencap -p > "$SCREENSHOT_DIR/phone_light.png"

# Toggle dark mode
adb shell cmd uimode night yes
sleep 2
adb exec-out screencap -p > "$SCREENSHOT_DIR/phone_dark.png"

# Reset to light mode
adb shell cmd uimode night no

# Set demo mode for clean status bar
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo \
  -e command clock -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo \
  -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo \
  -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo \
  -e command network -e mobile show -e level 4 -e datatype none

adb exec-out screencap -p > "$SCREENSHOT_DIR/phone_store.png"

# Exit demo mode
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

### 3. Screen Recording

```bash
# iOS Simulator recording
# Start recording
xcrun simctl io booted recordVideo --codec=h264 recording.mp4

# Stop with Ctrl+C, then the file is saved

# Android Emulator recording
adb shell screenrecord /sdcard/demo.mp4 --time-limit 60
adb pull /sdcard/demo.mp4 ./recordings/demo.mp4

# Convert to GIF for documentation (requires ffmpeg)
ffmpeg -i recording.mp4 -vf "fps=15,scale=320:-1" -loop 0 demo.gif
```

### 4. Demo Flow Script

Create reproducible demo flows with timed actions:

```typescript
// scripts/demo-flow.ts
interface DemoStep {
  /** Step description for presenter notes */
  description: string;
  /** Screen to navigate to */
  screen: string;
  /** Actions to perform */
  actions: DemoAction[];
  /** Pause duration in seconds before next step */
  pauseSeconds: number;
  /** Screenshot filename to capture */
  screenshotName?: string;
}

interface DemoAction {
  type: 'tap' | 'type' | 'scroll' | 'swipe' | 'wait';
  target?: string;
  value?: string;
  direction?: 'up' | 'down' | 'left' | 'right';
}

const demoFlow: DemoStep[] = [
  {
    description: 'Show the login screen',
    screen: 'LoginScreen',
    actions: [],
    pauseSeconds: 2,
    screenshotName: '01_login',
  },
  {
    description: 'Enter credentials and sign in',
    screen: 'LoginScreen',
    actions: [
      { type: 'tap', target: 'email-input' },
      { type: 'type', target: 'email-input', value: 'demo@example.com' },
      { type: 'tap', target: 'password-input' },
      { type: 'type', target: 'password-input', value: '********' },
      { type: 'tap', target: 'sign-in-button' },
    ],
    pauseSeconds: 3,
    screenshotName: '02_signing_in',
  },
  {
    description: 'Home feed with content loaded',
    screen: 'HomeScreen',
    actions: [
      { type: 'wait', value: '2000' },
    ],
    pauseSeconds: 3,
    screenshotName: '03_home_feed',
  },
  {
    description: 'Scroll through feed',
    screen: 'HomeScreen',
    actions: [
      { type: 'scroll', direction: 'down' },
      { type: 'wait', value: '1000' },
      { type: 'scroll', direction: 'down' },
    ],
    pauseSeconds: 2,
    screenshotName: '04_feed_scrolled',
  },
  {
    description: 'Open detail view',
    screen: 'HomeScreen',
    actions: [
      { type: 'tap', target: 'feed-item-0' },
    ],
    pauseSeconds: 3,
    screenshotName: '05_detail',
  },
];
```

### 5. Detox/Maestro-Based Screenshot Automation

```yaml
# .maestro/screenshot-flow.yaml
appId: com.example.myapp
---
- launchApp
- waitForAnimationToEnd

# Screenshot 1: Onboarding
- takeScreenshot: screenshots/01_onboarding

# Screenshot 2: Login
- tapOn: "Get Started"
- waitForAnimationToEnd
- takeScreenshot: screenshots/02_login

# Screenshot 3: Home Feed
- tapOn:
    id: "email-input"
- inputText: "demo@example.com"
- tapOn:
    id: "password-input"
- inputText: "password123"
- tapOn: "Sign In"
- waitForAnimationToEnd
- takeScreenshot: screenshots/03_home

# Screenshot 4: Profile
- tapOn:
    id: "tab-profile"
- waitForAnimationToEnd
- takeScreenshot: screenshots/04_profile

# Screenshot 5: Settings
- tapOn: "Settings"
- waitForAnimationToEnd
- takeScreenshot: screenshots/05_settings
```

### 6. App Store Screenshot Specification

```typescript
// Apple App Store requirements
const appStoreScreenshots = {
  required: {
    'iPhone 6.7"': { width: 1290, height: 2796, devices: ['iPhone 15 Pro Max'] },
    'iPhone 6.1"': { width: 1179, height: 2556, devices: ['iPhone 15 Pro'] },
  },
  optional: {
    'iPad 12.9"': { width: 2048, height: 2732, devices: ['iPad Pro 12.9"'] },
    'iPad 11"':   { width: 1668, height: 2388, devices: ['iPad Pro 11"'] },
  },
  limits: { min: 3, max: 10, perLocalization: true },
};

// Google Play Store requirements
const playStoreScreenshots = {
  phone: { minWidth: 320, maxWidth: 3840, minHeight: 320, maxHeight: 3840, aspect: '16:9 or taller' },
  tablet7: { minWidth: 320, maxWidth: 3840 },
  tablet10: { minWidth: 320, maxWidth: 3840 },
  limits: { min: 2, max: 8 },
};
```

### 7. Device Frame Overlay

```bash
# Using frameit (part of Fastlane) to add device frames
# Install: gem install fastlane
# Setup: fastlane frameit setup

# Add frames to all screenshots in a directory
fastlane frameit silver  # or "black" for dark frames

# Custom text overlay via Framefile.json
cat > ./screenshots/Framefile.json << 'EOF'
{
  "default": {
    "keyword": {
      "font": "./fonts/SF-Pro-Display-Bold.otf",
      "font_size": 64,
      "color": "#000000"
    },
    "title": {
      "font": "./fonts/SF-Pro-Display-Regular.otf",
      "font_size": 36,
      "color": "#666666"
    },
    "background": "#FFFFFF",
    "padding": 50
  }
}
EOF
```

## Why This Works

Automated screenshot capture ensures consistency across submissions and eliminates the most common App Store rejection reason related to screenshots: incorrect device sizes. The demo flow scripting makes presentations reproducible, so the same demo works every time without relying on live app state. Clean status bar overrides remove distracting clock times and low-battery indicators that undermine professionalism.

## Edge Cases

- **Localized screenshots**: run the capture script once per locale, setting the simulator language via `xcrun simctl spawn booted defaults write -g AppleLocale -string "fr_FR"`
- **Dynamic content**: seed the app with demo data before capture; use a `DEMO_MODE` environment variable to load fixtures
- **Animations during capture**: add appropriate wait times or disable animations for screenshots (`UIView.setAnimationsEnabled(false)`)
- **Notch/Dynamic Island variations**: capture on devices with and without Dynamic Island to ensure the UI does not clip
- **Dark mode store screenshots**: Apple allows mixing light and dark screenshots, but consistency within a locale is recommended

## Verification

1. **Resolution check**: verify all screenshots match the required pixel dimensions for each store
2. **Status bar cleanliness**: confirm time is 9:41, battery is full, and signal bars are complete
3. **Content accuracy**: screenshots show real (or realistic demo) content, not placeholder text
4. **Dark mode coverage**: if submitting dark mode screenshots, verify all screens are captured in dark mode
5. **Frame alignment**: device frames are centered and do not crop screen content

## References

- Apple App Store Screenshot Specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Google Play Screenshot Requirements: https://support.google.com/googleplay/android-developer/answer/9866151
- xcrun simctl Documentation: `xcrun simctl help`
- Fastlane Frameit: https://docs.fastlane.tools/actions/frameit/
- Maestro Mobile Testing: https://maestro.mobile.dev
