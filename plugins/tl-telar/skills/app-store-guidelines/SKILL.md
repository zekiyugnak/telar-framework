---
name: "app-store-guidelines"
description: "App Store rejections delay releases by 1-2 weeks and force costly rework. Guideline 2.1 (Performance: App Completeness) alone accounts for over 30% of all rejections. This skill covers every common rejection reason with "
source_type: "skill"
source_file: "skills/app-store-guidelines.md"
---

# app-store-guidelines

Migrated from `skills/app-store-guidelines.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Prevent App Store Rejections by Addressing the Top 20 Failure Reasons

App Store rejections delay releases by 1-2 weeks and force costly rework. Guideline 2.1 (Performance: App Completeness) alone accounts for over 30% of all rejections. This skill covers every common rejection reason with specific, actionable fixes.

## Problem

An app submitted without review preparation crashes on the reviewer's device or triggers policy flags.

```typescript
// BAD: App crashes because a feature requires login but no demo account
// was provided in App Review notes
function ProfileScreen() {
  // Crashes with "Cannot read property 'name' of undefined"
  // when reviewer opens this screen without being authenticated
  const user = useAuth().currentUser;

  return (
    <View>
      <Text>{user.name}</Text>
      <Text>{user.email}</Text>
      <Image source={{ uri: user.avatarUrl }} />
    </View>
  );
}

// BAD: External payment link for digital goods (violates Guideline 3.1.1)
function SubscriptionScreen() {
  return (
    <View>
      <Text>Upgrade to Premium</Text>
      <Button
        title="Subscribe on our website"
        onPress={() => Linking.openURL('https://myapp.com/subscribe')}
      />
    </View>
  );
}

// BAD: Missing privacy usage descriptions (Guideline 5.1.1)
// Info.plist has no NSCameraUsageDescription but app uses camera
// Reviewer sees system permission dialog with blank reason -> instant rejection
```

```xml
<!-- BAD: Info.plist with missing or vague privacy descriptions -->
<key>NSCameraUsageDescription</key>
<string>Camera access needed</string>
<!-- Too vague. Reviewer wants to know WHY specifically. -->

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location</string>
<!-- Requesting "Always" without justification triggers Guideline 5.1.2 -->

<!-- MISSING: NSUserTrackingUsageDescription when using IDFA -->
<!-- MISSING: NSPhotoLibraryUsageDescription when saving images -->
```

## Solution

### Top 20 Rejection Reasons with Specific Fixes

```markdown
## Guideline 2.1 - Performance: App Completeness (Rank #1, ~30% of rejections)
REASON: App crashes, has broken features, or placeholder content.
FIX: Test on physical devices matching Apple's review hardware (latest
     iPhone with current iOS). Provide demo credentials in App Review notes.
     Handle nil/null states for every data-dependent screen.

## Guideline 2.3.3 - Accurate Screenshots
REASON: Screenshots show features that do not exist or look different.
FIX: Regenerate screenshots from the actual build being submitted.
     Use fastlane snapshot to automate this per release.

## Guideline 3.1.1 - In-App Purchase Requirement
REASON: Digital goods/services purchased outside Apple's IAP system.
FIX: Use StoreKit for ALL digital content purchases. Physical goods and
     services consumed outside the app (e.g., Uber rides) are exempt.
     "Reader" apps (Netflix, Spotify) may not include purchase links.

## Guideline 3.1.2 - Subscriptions
REASON: Missing subscription management or unclear terms.
FIX: Link to Apple subscription management. Show price, duration,
     renewal terms, and cancellation instructions before purchase.

## Guideline 4.0 - Design: Minimum Functionality
REASON: App is a thin wrapper around a website or too simple.
FIX: Ensure native functionality beyond what a bookmark provides.
     Add offline support, push notifications, or native UI elements.

## Guideline 4.2 - Minimum Functionality (Copycat/Spam)
REASON: App duplicates existing functionality with no differentiation.
FIX: Document unique value proposition in review notes.

## Guideline 5.1.1 - Data Collection and Storage
REASON: App collects data without adequate privacy policy or consent.
FIX: Link a privacy policy URL in App Store Connect AND inside the app.
     Implement consent flows before collecting any personal data.

## Guideline 5.1.2 - Data Use and Sharing
REASON: Using data for purposes not disclosed to the user.
FIX: Declare all data usage in privacy nutrition labels. Match labels
     to actual SDK behavior (e.g., Firebase Analytics collects device ID).

## Guideline 2.5.1 - Software Requirements (Private APIs)
REASON: App uses private Apple APIs or undocumented frameworks.
FIX: Run `nm -u YourApp | grep _OBJC_CLASS` to find private symbols.
     Remove any non-public API usage.

## Guideline 2.5.4 - Multitasking / Background Modes
REASON: App declares background modes it does not actually use.
FIX: Only enable background modes in Info.plist that are actively used.
     Remove audio, location, fetch modes if not needed.

## Guideline 1.2 - User Generated Content
REASON: UGC features lack moderation, reporting, and blocking.
FIX: Implement content reporting, user blocking, and content filtering
     for any user-generated text, images, or videos.

## Guideline 2.1 - Performance: IPv6 Compatibility
REASON: App fails on IPv6-only networks (Apple review uses IPv6).
FIX: Do not hard-code IPv4 addresses. Use hostnames and test with
     macOS Internet Sharing IPv6 NAT64 network.

## Guideline 3.2.2 - Unacceptable Business Model
REASON: App exists solely to drive traffic to a website.
FIX: Provide substantial native functionality independent of website.

## Guideline 4.3 - Spam / App Similarity
REASON: Multiple similar apps submitted from same developer.
FIX: Consolidate functionality into a single app.

## Guideline 5.1.5 - Apple Sign-In Requirement
REASON: App offers third-party sign-in (Google, Facebook) but not Apple.
FIX: If you offer ANY third-party sign-in, you MUST also offer
     Sign in with Apple as an equal option.

## Guideline 2.3.7 - Accurate App Descriptions
REASON: App description or what's new text is misleading.
FIX: Ensure description matches current build functionality exactly.

## Guideline 5.2.1 - Intellectual Property
REASON: App uses copyrighted material without authorization.
FIX: Ensure all assets, names, and content are original or licensed.

## Guideline 2.5.10 - Deprecated API Usage
REASON: App relies on APIs Apple has deprecated and removed.
FIX: Address all deprecation warnings in Xcode. Replace UIWebView
     with WKWebView. Update to current SDK patterns.

## Guideline 3.1.3(b) - Consumable IAP Restoration
REASON: Consumable purchases not handled correctly on restore.
FIX: Non-consumables and subscriptions must be restorable. Consumables
     should be delivered immediately and tracked server-side.

## Guideline 4.7 - HTML5 Games / Web Content
REASON: App is primarily a web view with no native functionality.
FIX: Add native navigation, offline caching, or native UI overlays
     to demonstrate value beyond a browser bookmark.
```

### Crash-Proof Screens with Safe Null Handling

```typescript
// GOOD: Screens handle unauthenticated state gracefully
function ProfileScreen() {
  const { currentUser, isLoading } = useAuth();

  if (isLoading) {
    return <LoadingSpinner />;
  }

  // Gracefully handle reviewer opening screen without login
  if (!currentUser) {
    return (
      <View style={styles.container}>
        <Text style={styles.title}>Sign in to view your profile</Text>
        <Button title="Sign In" onPress={() => navigation.navigate('Login')} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text>{currentUser.name ?? 'User'}</Text>
      <Text>{currentUser.email ?? ''}</Text>
      {currentUser.avatarUrl ? (
        <Image
          source={{ uri: currentUser.avatarUrl }}
          defaultSource={require('./assets/default-avatar.png')}
        />
      ) : (
        <DefaultAvatar />
      )}
    </View>
  );
}
```

### IAP Compliance (Guideline 3.1.1)

```typescript
// GOOD: Use StoreKit / react-native-iap for digital goods
import { requestSubscription, getSubscriptions } from 'react-native-iap';

const SUBSCRIPTION_SKUS = ['com.myapp.premium.monthly', 'com.myapp.premium.yearly'];

function SubscriptionScreen() {
  const [products, setProducts] = useState([]);

  useEffect(() => {
    async function loadProducts() {
      const subs = await getSubscriptions({ skus: SUBSCRIPTION_SKUS });
      setProducts(subs);
    }
    loadProducts();
  }, []);

  const handlePurchase = async (sku: string) => {
    try {
      await requestSubscription({ sku });
    } catch (err) {
      if (err.code === 'E_USER_CANCELLED') return;
      Alert.alert('Purchase failed', 'Please try again later.');
    }
  };

  return (
    <View>
      <Text style={styles.title}>Upgrade to Premium</Text>
      {products.map((product) => (
        <View key={product.productId}>
          <Text>{product.title}</Text>
          <Text>{product.localizedPrice} / {product.subscriptionPeriodUnitIOS}</Text>
          <Button title="Subscribe" onPress={() => handlePurchase(product.productId)} />
        </View>
      ))}
      {/* Required: Show subscription terms */}
      <Text style={styles.terms}>
        Payment will be charged to your Apple ID account at confirmation of purchase.
        Subscription automatically renews unless it is canceled at least 24 hours
        before the end of the current period. Your account will be charged for renewal
        within 24 hours prior to the end of the current period. You can manage and
        cancel your subscriptions by going to Settings {'>'} Apple ID {'>'} Subscriptions.
      </Text>
      <TouchableOpacity onPress={() => Linking.openURL('https://myapp.com/privacy')}>
        <Text style={styles.link}>Privacy Policy</Text>
      </TouchableOpacity>
      <TouchableOpacity onPress={() => Linking.openURL('https://myapp.com/terms')}>
        <Text style={styles.link}>Terms of Use</Text>
      </TouchableOpacity>
    </View>
  );
}
```

### Privacy Nutrition Labels Setup

```xml
<!-- GOOD: Info.plist - specific, honest privacy descriptions -->
<key>NSCameraUsageDescription</key>
<string>Take photos to attach to your support tickets or update your profile picture</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Select photos from your library to share in conversations or set as your profile picture</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Find stores, restaurants, and services near your current location on the map</string>

<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads based on your interests</string>

<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely unlock the app without entering your password</string>

<!-- Do NOT request NSLocationAlwaysAndWhenInUseUsageDescription unless
     you have a genuine background location use case (e.g., navigation app).
     "Always" location triggers extra scrutiny from reviewers. -->
```

```markdown
## Privacy Nutrition Labels in App Store Connect

For each data type, you must declare:
1. Whether you COLLECT it
2. Whether it is LINKED to the user's identity
3. Whether it is used for TRACKING

Common SDKs and their data collection:
- Firebase Analytics: Device ID, app interactions, crash logs
- Facebook SDK: Device ID, advertising ID, app interactions
- Google Sign-In: Name, email, user ID
- Sentry: Crash logs, device info
- Adjust/AppsFlyer: Advertising ID, device ID, purchase history

If ANY SDK in your app collects data, you must declare it even
if YOU do not directly use that data.
```

### Screenshot and Metadata Requirements

```markdown
## Required Screenshot Sizes (2024+)
- 6.7" display (iPhone 15 Pro Max): 1290 x 2796 px
- 6.5" display (iPhone 14 Plus): 1284 x 2778 px
- 5.5" display (iPhone 8 Plus): 1242 x 2208 px (optional if 6.5" provided)
- iPad Pro 12.9" (6th gen): 2048 x 2732 px
- iPad Pro 12.9" (2nd gen): 2048 x 2732 px (optional if 6th gen provided)

Rules:
- Minimum 2 screenshots, maximum 10 per localization
- Must show actual app UI (not just marketing graphics)
- Can include device frame overlays and text callouts
- Must not include status bar or misleading elements

## Metadata Limits
- App Name: 30 characters
- Subtitle: 30 characters
- Keywords: 100 characters (comma-separated, no spaces after commas)
- Description: 4000 characters
- What's New: 4000 characters
- Promotional Text: 170 characters (can be updated without new build)
- Review Notes: 500 characters
```

### TestFlight Best Practices

```markdown
## TestFlight Configuration

External Testing (up to 10,000 testers):
- Requires Beta App Review (usually 24-48 hours)
- Create test groups by audience (internal, beta, VIP)
- Use TestFlight feedback screenshots for bug reports

Internal Testing (up to 100 App Store Connect users):
- No Beta App Review required
- Builds available immediately after processing
- Use for QA team and stakeholders

Beta App Review Notes:
- Same standards as full App Review
- Provide demo credentials
- Mark features as "beta" if incomplete
- Include clear test instructions

Build Management:
- Auto-increment build numbers (use CI build number)
- Set build expiration to 90 days (default)
- Archive dSYMs for every TestFlight build for crash symbolication
```

### App Review Notes Template

```markdown
## App Review Notes (paste into App Store Connect)

Demo Account:
  Email: demo@example.com
  Password: ReviewDemo2024!

Testing Instructions:
1. Sign in with the demo account above
2. The home screen shows sample data pre-loaded
3. To test the subscription flow:
   - Navigate to Settings > Premium
   - Use sandbox Apple ID (auto-provided in review environment)
4. To test camera features:
   - Navigate to Profile > Edit > Change Photo
   - Both camera and photo library options are functional

Environment Notes:
- Push notifications will not function during review
- Location features default to San Francisco if location unavailable
- The app supports IPv6-only networks (tested with NAT64)

Hardware Requirements: None (all features work on standard iPhone hardware)
```

## Why This Works

- **Guideline 2.1 accounts for 30%+ of rejections** because reviewers test on real devices with real accounts. Handling null/loading states prevents the most common crash scenario during review.
- **Guideline 3.1.1** is strictly enforced: any digital good purchased outside IAP results in immediate rejection. Using `react-native-iap` or StoreKit ensures Apple receives their commission and the app passes review.
- **Privacy nutrition labels** must match actual SDK data collection. Apple runs automated scans that cross-reference declared APIs (via entitlements) against your privacy declarations.
- **Specific usage descriptions** in Info.plist explain the value to the user, which is what reviewers look for. Vague descriptions trigger rejections because they suggest the developer does not have a legitimate use case.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS 17+:**
- `NSUserTrackingUsageDescription` must be present if using IDFA, even if you never call `requestTrackingAuthorization()`
- StoreKit 2 simplifies subscription management but requires iOS 15+. If supporting iOS 14, use original StoreKit API.

**App Clips:**
- App Clips have a separate review process and 15MB size limit
- Must not require sign-in before core functionality

### Common Mistakes

- **Submitting on Friday** - review queue is longest over weekends. Submit Monday-Wednesday for faster turnaround.
- **Not testing on the latest iOS beta** - reviewers often use the latest iOS release within days of its launch.
- **Forgetting to update nutrition labels after adding a new SDK** - adding Firebase Crashlytics means declaring crash log collection.
- **Using `UIWebView`** - deprecated since iOS 12 and now rejected. Must use `WKWebView` everywhere.
- **Requesting permissions on first launch** - ask for permissions in context (e.g., camera permission when user taps "Take Photo", not at app startup).

## Verification

```bash
# Check for private API usage
nm -u YourApp.app/YourApp | grep _OBJC_CLASS | sort

# Check for UIWebView references (must be zero)
grep -r "UIWebView" ios/ --include="*.m" --include="*.swift" --include="*.h"

# Validate Info.plist has all required keys
/usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" ios/YourApp/Info.plist
/usr/libexec/PlistBuddy -c "Print :NSPhotoLibraryUsageDescription" ios/YourApp/Info.plist

# Run on physical device with release build
npx react-native run-ios --mode Release --device "iPhone"
```

- [ ] App launches and all screens load without crash on physical device
- [ ] Demo account credentials work and are included in review notes
- [ ] All IAP products load and display correct prices
- [ ] Privacy descriptions are specific and match actual feature usage
- [ ] Screenshots match the submitted build exactly
- [ ] Sign in with Apple is offered alongside any third-party sign-in
- [ ] No UIWebView references exist in the codebase
- [ ] Background modes in Info.plist match actual background features used

## References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Common App Rejections (Apple)](https://developer.apple.com/app-store/review/rejections/)
- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [StoreKit 2 Documentation](https://developer.apple.com/storekit/)
- [App Privacy Details (Nutrition Labels)](https://developer.apple.com/app-store/app-privacy-details/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
