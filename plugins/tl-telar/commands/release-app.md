---
id: release-app
name: Release App
description: Full release workflow with pre-release checks, builds, store submission, and monitoring
category: command
usage: /tl-telar:release-app [platform]
example: /tl-telar:release-app to App Store and Play Store
phases:
  - name: Pre-Release Checks
    progress: 0-20%
  - name: Build
    progress: 20-40%
  - name: Store Submission
    progress: 40-70%
  - name: Post-Release
    progress: 70-90%
  - name: Monitoring
    progress: 90-100%
---

# Release App

Full mobile app release workflow.

## Phase 1: Pre-Release Checks (0-20%)

### Load Agents
```yaml
agents:
  - mobile-release-manager
  - mobile-code-signing-expert
```

### Version Check
```bash
# Verify version is updated
# package.json / pubspec.yaml
# ios/MyApp/Info.plist
# android/app/build.gradle
```

### Pre-Release Checklist
```markdown
Code Quality:
- [ ] All tests passing
- [ ] No linting errors
- [ ] Code review completed
- [ ] No debug code in production

Features:
- [ ] All planned features implemented
- [ ] Feature flags configured correctly
- [ ] Analytics events added

Content:
- [ ] Release notes written
- [ ] Screenshots updated (if UI changed)
- [ ] App Store/Play Store description updated
```

### Fresh Verification
```yaml
skills:
  - verification-before-completion
```
- All checklist items must be verified fresh — do not rely on earlier test runs
- Run full test suite and confirm pass before proceeding to build
- If any test fails, route through `systematic-debugging` before fixing

### Dependency Check
```bash
# Check for security vulnerabilities
npm audit
npx snyk test

# Ensure no outdated critical deps
yarn outdated
```

### Output
- Pre-release checklist complete
- Version verified
- Ready for build

## Phase 2: Build (20-40%)

### Load Skills
```yaml
skills:
  - ios-provisioning
  - android-signing
```

### iOS Build
```bash
# Using Fastlane
fastlane ios release

# Or manual
xcodebuild -workspace ios/MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Release \
  -archivePath build/MyApp.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath build/MyApp.xcarchive \
  -exportOptionsPlist exportOptions.plist \
  -exportPath build/
```

### Android Build
```bash
# Using Fastlane
fastlane android release

# Or manual
cd android && ./gradlew bundleRelease

# Sign AAB
jarsigner -keystore release.keystore \
  app/build/outputs/bundle/release/app-release.aab \
  my-key-alias
```

### Expo/EAS Build
```bash
# Build for both platforms
eas build --platform all --profile production

# Or separately
eas build --platform ios --profile production
eas build --platform android --profile production
```

### Build Verification
- Verify build size
- Test on physical device
- Check crash reporting integration

### Output
- iOS IPA/archive ready
- Android AAB ready
- Builds verified

## Phase 3: Store Submission (40-70%)

### Load Agents
```yaml
agents:
  - ios-app-store-specialist
  - google-play-specialist
```

### Load Skills
```yaml
skills:
  - app-store-guidelines
  - play-store-policies
```

### App Store Connect
```bash
# Using Fastlane
fastlane deliver --ipa ./build/MyApp.ipa

# Or Transporter
xcrun altool --upload-app -f MyApp.ipa \
  -u apple@email.com \
  -p @keychain:AC_PASSWORD
```

### App Store Metadata
```markdown
Required:
- [ ] App name
- [ ] Subtitle
- [ ] Description
- [ ] Keywords
- [ ] Screenshots (all sizes)
- [ ] App preview video (optional)
- [ ] Privacy policy URL
- [ ] Support URL
```

### Google Play Console
```bash
# Using Fastlane
fastlane supply --aab ./app-release.aab

# Or manual upload via Play Console
```

### Play Store Metadata
```markdown
Required:
- [ ] Title
- [ ] Short description
- [ ] Full description
- [ ] Screenshots
- [ ] Feature graphic
- [ ] Data safety section
- [ ] Content rating
```

### Submission Settings
- Phased release (recommended)
- Manual vs automatic release
- Territory selection

### Output
- iOS submitted to App Store
- Android submitted to Play Store
- Review pending

## Phase 4: Post-Release (70-90%)

### Review Monitoring
```markdown
App Store:
- Average review time: 24-48 hours
- Check App Store Connect for status
- Respond to review questions promptly

Play Store:
- Average review time: few hours - 7 days
- Check Play Console for status
- Watch for policy warnings
```

### Staged Rollout
```markdown
Recommended stages:
- Day 1: 1% - Monitor for crashes
- Day 2: 5% - Check user feedback
- Day 3: 20% - Broader testing
- Day 5: 50% - Pre-full release
- Day 7: 100% - Full release
```

### Rollback Plan
```markdown
If critical issues:
1. Pause staged rollout
2. Assess impact
3. Fix and submit new build
4. Or rollback to previous version
```

### Output
- Apps in review/released
- Staged rollout configured

## Phase 5: Monitoring (90-100%)

### Load Skills
```yaml
skills:
  - crash-reporting
  - staged-rollouts
```

### Crash Monitoring
```markdown
Tools:
- Firebase Crashlytics
- Sentry
- Bugsnag

Metrics to watch:
- Crash-free rate (target: >99.5%)
- ANR rate (Android)
- New crash patterns
```

### User Feedback
- Monitor app store reviews
- Check support channels
- Watch social media

### Analytics
```markdown
Key metrics:
- DAU/MAU after release
- Retention rates
- Feature adoption
- Funnel conversion
```

### Post-Release Checklist
```markdown
- [ ] Crash rate acceptable
- [ ] No critical bugs reported
- [ ] Analytics tracking working
- [ ] User feedback positive
- [ ] Staged rollout progressing
```

### Output
- Monitoring active
- Release successful

## Completion Checklist

- [ ] Pre-release checks passed
- [ ] Builds created and verified
- [ ] Submitted to App Store
- [ ] Submitted to Play Store
- [ ] Review approved
- [ ] Staged rollout configured
- [ ] Monitoring active
- [ ] Release notes published
