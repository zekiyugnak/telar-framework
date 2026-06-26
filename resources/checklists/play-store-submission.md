# Google Play Store Submission Checklist

Step-by-step checklist for submitting to the Google Play Store.

## Pre-Submission

### App Configuration
- [ ] Application ID (package name) matches Play Console
- [ ] versionCode incremented (integer, must be higher than previous)
- [ ] versionName updated (user-visible version string)
- [ ] minSdkVersion set appropriately
- [ ] targetSdkVersion meets current Google Play requirement (API 34+)
- [ ] App icons provided (512x512 hi-res icon)
- [ ] Adaptive icon configured (foreground + background layers)

### Signing
- [ ] App signed with upload key (Play App Signing enabled)
- [ ] Upload key securely stored (not in version control)
- [ ] Key alias and passwords documented securely
- [ ] Play App Signing enrolled (recommended for key recovery)

### Privacy & Compliance
- [ ] Data Safety form completed accurately
- [ ] Privacy policy URL set and publicly accessible
- [ ] Account deletion capability implemented (if app has accounts)
- [ ] Families Policy compliance (if targeting children)
- [ ] Permission declarations justified (only request necessary permissions)
- [ ] Sensitive permissions documented (CAMERA, LOCATION, etc.)

### Content
- [ ] No placeholder content
- [ ] All features functional
- [ ] No deceptive behavior or misleading descriptions
- [ ] Intellectual property rights verified
- [ ] Content rating questionnaire completed

## Build

### APK/AAB Preparation
- [ ] Build as Android App Bundle (AAB) - required for new apps
- [ ] ProGuard/R8 minification enabled
- [ ] Resource shrinking enabled
- [ ] Native debug symbols uploaded for crash reporting
- [ ] APK/AAB size within limits (150MB for AAB download size)

### Testing
- [ ] Tested on physical devices (multiple Android versions)
- [ ] Tested on oldest supported API level
- [ ] Tested on small, medium, and large screens
- [ ] Tested with Developer Options enabled (strict mode, layout bounds)
- [ ] Firebase Test Lab or similar automated testing run
- [ ] In-app billing tested with license testers
- [ ] Deep links verified
- [ ] Push notifications work
- [ ] ANR-free (no Application Not Responding)

## Play Console

### Store Listing
- [ ] App title (30 character limit)
- [ ] Short description (80 character limit)
- [ ] Full description (4000 character limit)
- [ ] Feature graphic (1024x500)
- [ ] Phone screenshots (2-8, minimum 320px, 16:9 or 9:16)
- [ ] 7-inch tablet screenshots (if applicable)
- [ ] 10-inch tablet screenshots (if applicable)
- [ ] Video URL (YouTube, optional but recommended)
- [ ] Category selected

### Data Safety
- [ ] Data collection types declared for each SDK
- [ ] Data sharing practices documented
- [ ] Data handling practices (encryption, deletion) declared
- [ ] Common SDKs covered:
  - [ ] Firebase Analytics
  - [ ] Crashlytics
  - [ ] Google Ads
  - [ ] Facebook SDK
  - [ ] Supabase/custom backend

### Content Rating
- [ ] IARC questionnaire completed
- [ ] Rating accurate for all regions
- [ ] Re-rate if adding new content types

### Release Management
- [ ] Select correct track (internal → closed → open → production)
- [ ] Start with staged rollout (not 100%)
- [ ] Release notes written for this version
- [ ] Country/region availability configured

## Post-Submission

- [ ] Monitor Play Console for review status (usually 1-3 days)
- [ ] Check for policy violation emails
- [ ] Monitor Android Vitals after release
  - [ ] ANR rate < 0.47%
  - [ ] Crash rate < 1.09%
  - [ ] Excessive wakeups
  - [ ] Stuck partial wake locks
- [ ] Monitor user reviews
- [ ] Respond to 1-star reviews with helpful guidance
