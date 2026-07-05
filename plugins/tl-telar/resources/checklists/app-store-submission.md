# iOS App Store Submission Checklist

Step-by-step checklist for submitting to the Apple App Store.

## Pre-Submission

### App Configuration
- [ ] Bundle identifier matches App Store Connect
- [ ] Version number incremented (CFBundleShortVersionString)
- [ ] Build number incremented (CFBundleVersion)
- [ ] Deployment target set correctly (minimum iOS version)
- [ ] All device orientations configured correctly
- [ ] App icons provided for all required sizes (1024x1024 App Store icon)
- [ ] Launch screen configured (no static launch images)

### Code Signing
- [ ] Distribution certificate is valid and not expiring soon
- [ ] Provisioning profile includes all required capabilities
- [ ] Entitlements file matches provisioning profile
- [ ] Push notification entitlement matches environment (production vs development)
- [ ] Associated Domains configured if using universal links

### Privacy & Compliance
- [ ] Privacy nutrition labels completed in App Store Connect
- [ ] NSPrivacyAccessedAPITypes declared in PrivacyInfo.xcprivacy
- [ ] Required reason APIs documented (UserDefaults, file timestamp, etc.)
- [ ] App Tracking Transparency implemented if using IDFA
- [ ] Privacy policy URL set and accessible
- [ ] Data collection practices accurately declared
- [ ] GDPR/CCPA consent flows implemented if applicable

### Content & Design
- [ ] App does not use private APIs
- [ ] No placeholder content or "lorem ipsum" text
- [ ] All links functional (no broken URLs)
- [ ] Login demo account provided in App Review notes
- [ ] App works offline or shows appropriate offline state
- [ ] No references to other platforms ("available on Android")

## Build & Archive

### Build Preparation
- [ ] Clean build folder (Product → Clean Build Folder)
- [ ] Archive with Release configuration
- [ ] Bitcode setting matches requirements
- [ ] Strip debug symbols enabled for Release
- [ ] dSYM files generated for crash reporting

### Testing
- [ ] Tested on physical devices (not just simulator)
- [ ] Tested on oldest supported iOS version
- [ ] Tested on both iPhone and iPad (if universal)
- [ ] Memory usage under 200MB on older devices
- [ ] No crashes in crash reporting from TestFlight
- [ ] Deep links work correctly
- [ ] Push notifications work in production environment
- [ ] In-app purchases complete successfully (sandbox)
- [ ] Background modes work correctly

## App Store Connect

### Metadata
- [ ] App name (30 character limit)
- [ ] Subtitle (30 character limit)
- [ ] Description (4000 character limit, first 3 lines most important)
- [ ] Keywords (100 character limit, comma-separated)
- [ ] Support URL provided
- [ ] Marketing URL provided (optional but recommended)
- [ ] What's New text written for this version
- [ ] Category and subcategory selected

### Screenshots
- [ ] 6.7" display (iPhone 15 Pro Max) - required
- [ ] 6.5" display (iPhone 14 Plus) - required
- [ ] 5.5" display (iPhone 8 Plus) - if supporting older devices
- [ ] iPad Pro 12.9" (6th gen) - if universal app
- [ ] iPad Pro 12.9" (2nd gen) - if supporting older iPads
- [ ] Minimum 3 screenshots per device size
- [ ] Screenshots show actual app functionality
- [ ] No device bezels unless using Apple-provided frames

### Review Information
- [ ] Contact information for reviewer
- [ ] Demo account credentials (if login required)
- [ ] Notes explaining non-obvious features
- [ ] Attachment with video walkthrough (if complex app)

## Post-Submission

- [ ] Monitor App Store Connect for review status
- [ ] Respond to reviewer questions within 24 hours
- [ ] If rejected, read rejection reason carefully before resubmitting
- [ ] Verify app appears correctly on App Store after approval
- [ ] Monitor crash reports for first 24-48 hours
- [ ] Check user reviews for issues
