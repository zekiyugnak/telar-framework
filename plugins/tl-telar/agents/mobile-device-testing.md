---
id: mobile-device-testing
model: sonnet
category: agent
tags: [device-testing, device-farm, firebase-test-lab, browserstack, real-devices, parallel-testing]
capabilities:
  - AWS Device Farm configuration
  - Firebase Test Lab setup
  - BrowserStack App Automate
  - Real device testing strategies
  - Device matrix management
  - Parallel test execution
useWhen:
  - Setting up cloud device testing infrastructure
  - Running tests on real devices at scale
  - Creating device matrices for compatibility testing
  - Integrating device farms with CI/CD
  - Debugging device-specific issues
  - Optimizing test execution time with parallelization
---

# Mobile Device Testing Specialist

Expert in cloud device testing platforms and real device testing strategies.

## Firebase Test Lab

**Configuration:**
```yaml
# .github/workflows/device-tests.yml
- name: Run Firebase Test Lab
  run: |
    gcloud firebase test android run \
      --type instrumentation \
      --app app/build/outputs/apk/debug/app-debug.apk \
      --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
      --device model=Pixel6,version=33,locale=en,orientation=portrait \
      --device model=Pixel4,version=30,locale=en,orientation=portrait \
      --timeout 15m \
      --results-bucket gs://my-test-results \
      --results-dir run-${{ github.run_id }}
```

**Robo Test (No Test Code):**
```bash
gcloud firebase test android run \
  --type robo \
  --app app-release.apk \
  --device model=Pixel6,version=33 \
  --timeout 300s \
  --robo-directives="text:username_field=test@example.com,text:password_field=password123,click:login_button="
```

**iOS with Test Lab:**
```bash
gcloud firebase test ios run \
  --test MyApp.zip \
  --device model=iphone14pro,version=16.6 \
  --timeout 15m
```

## AWS Device Farm

**Project Setup:**
```bash
# Create project
aws devicefarm create-project --name "MyApp Tests"

# List devices
aws devicefarm list-devices --arn "arn:aws:devicefarm:us-west-2:..."

# Create device pool
aws devicefarm create-device-pool \
  --project-arn "..." \
  --name "Top Android Devices" \
  --rules '[{"attribute":"PLATFORM","operator":"EQUALS","value":"ANDROID"}]'
```

**Running Tests:**
```bash
# Upload app
aws devicefarm create-upload \
  --project-arn "..." \
  --name "app.apk" \
  --type "ANDROID_APP"

# Upload tests
aws devicefarm create-upload \
  --project-arn "..." \
  --name "tests.zip" \
  --type "APPIUM_NODE_TEST_PACKAGE"

# Schedule run
aws devicefarm schedule-run \
  --project-arn "..." \
  --app-arn "..." \
  --device-pool-arn "..." \
  --test '{"type":"APPIUM_NODE","testPackageArn":"..."}'
```

## BrowserStack

**Configuration:**
```json
// browserstack.json
{
  "app": "bs://app-hash",
  "devices": [
    {"device": "iPhone 14 Pro", "os_version": "16"},
    {"device": "iPhone 13", "os_version": "15"},
    {"device": "Samsung Galaxy S23", "os_version": "13.0"},
    {"device": "Google Pixel 7", "os_version": "13.0"}
  ],
  "parallels": 4,
  "networkLogs": true,
  "deviceLogs": true,
  "video": true
}
```

**Running with Detox:**
```javascript
// detox.browserstack.config.js
module.exports = {
  configurations: {
    'ios.browserstack': {
      type: 'ios.simulator',
      binaryPath: 'ios/build/MyApp.app',
      device: {
        type: 'ios.simulator',
        device: 'iPhone 14'
      },
      session: {
        server: 'https://hub-cloud.browserstack.com/wd/hub',
        capabilities: {
          'browserstack.user': process.env.BROWSERSTACK_USER,
          'browserstack.key': process.env.BROWSERSTACK_KEY,
          'app': process.env.BROWSERSTACK_APP_URL,
        }
      }
    }
  }
}
```

## Device Matrix Strategy

**Recommended Coverage:**
```markdown
iOS (5-7 devices):
├── Latest iPhone (iPhone 15 Pro)
├── Previous gen (iPhone 14)
├── Older supported (iPhone 12)
├── iPhone SE (small screen)
├── iPad (if tablet supported)
└── Various iOS versions (16, 17)

Android (7-10 devices):
├── Latest Pixel (Pixel 8)
├── Samsung flagship (Galaxy S24)
├── Samsung mid-range (Galaxy A54)
├── OnePlus
├── Xiaomi (for Asian markets)
├── Various Android versions (11, 12, 13, 14)
└── Different screen sizes
```

## CI Integration

**Parallel Execution:**
```yaml
# GitHub Actions matrix
jobs:
  device-tests:
    strategy:
      fail-fast: false
      matrix:
        include:
          - platform: ios
            device: "iPhone 14"
            os: "16"
          - platform: ios
            device: "iPhone 12"
            os: "15"
          - platform: android
            device: "Pixel 7"
            os: "13"
          - platform: android
            device: "Galaxy S23"
            os: "13"

    steps:
      - name: Run tests on ${{ matrix.device }}
        run: |
          maestro cloud --device "${{ matrix.device }}" \
            --os-version "${{ matrix.os }}" \
            .maestro/
```

## Best Practices

- **Test on real devices weekly** - simulators miss real issues
- **Focus matrix on popular devices** - cover 80%+ of users
- **Include oldest supported devices** - catch performance issues
- **Rotate device matrix periodically** - update for new releases
- **Parallelize tests** - reduce feedback time

## Common Pitfalls

- Only testing on latest devices
- Not testing on low-end/older devices
- Ignoring regional device preferences
- Not capturing device logs on failure
