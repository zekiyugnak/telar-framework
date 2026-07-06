---
name: "play-store-policies"
description: "Google Play suspensions can be permanent and take weeks to appeal. Unlike Apple's pre-publication review, Google often acts after publication, suspending live apps with active users. Missing Data Safety declarations alon"
source_type: "skill"
source_file: "skills/play-store-policies.md"
---

# play-store-policies

Migrated from `skills/play-store-policies.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Prevent Play Store Suspension by Addressing Policy Violations Before Submission

Google Play suspensions can be permanent and take weeks to appeal. Unlike Apple's pre-publication review, Google often acts after publication, suspending live apps with active users. Missing Data Safety declarations alone caused mass suspensions in 2023-2024. This skill covers every major policy area with concrete fixes.

## Problem

An app is published without a complete Data Safety section, triggering automatic suspension.

```groovy
// BAD: build.gradle - outdated target SDK triggers policy warning
android {
    compileSdkVersion 31
    defaultConfig {
        targetSdkVersion 31  // Google requires 34+ for new apps (2024+)
        minSdkVersion 21
    }
}
// Result: App update rejected with "Target API level requirement not met"
```

```markdown
// BAD: Data Safety form left incomplete
Data Safety Section Status: INCOMPLETE

Missing declarations for:
- Firebase Analytics (collects device ID, app interactions)
- Google AdMob (collects advertising ID, location, device info)
- Sentry (collects crash logs, device info)
- Facebook Login SDK (collects user ID, email, friends list)

Result: App suspended with notice:
"Issue: Violation of Data Safety section policy.
Your app's Data Safety section does not accurately represent
the data collected and shared by your app."
```

```kotlin
// BAD: No privacy policy accessible in-app
class SettingsFragment : Fragment() {
    // No link to privacy policy
    // No way for user to request data deletion
    // No disclosure of third-party data sharing
}

// BAD: Subscription without clear disclosure
class SubscriptionActivity : AppCompatActivity() {
    fun subscribe() {
        // Charges user without showing:
        // - Price and billing period
        // - Free trial duration and what happens after
        // - How to cancel
        startPayment(SKU_PREMIUM_MONTHLY)
    }
}
```

## Solution

### Top 20 Rejection and Suspension Reasons with Fixes

```markdown
## 1. Incomplete Data Safety Section (Most common suspension trigger)
REASON: Data Safety form does not match actual app data collection.
FIX: Audit every SDK and library. Declare ALL data collection even if
     performed by third-party SDKs. See Data Safety guide below.

## 2. Target API Level Not Met
REASON: App targets SDK version below Google's minimum requirement.
FIX: Update targetSdkVersion to 34+ (2024 requirement). New apps
     and updates will be blocked if below the required level.

## 3. Missing Privacy Policy
REASON: No privacy policy linked in Play Console AND accessible in-app.
FIX: Host privacy policy at a stable URL. Link it in:
     (a) Play Console store listing, (b) in-app settings screen.

## 4. Deceptive Behavior
REASON: App contains hidden functionality or misrepresents features.
FIX: Ensure all declared features work. Remove hidden admin APIs,
     undisclosed data exfiltration, or functionality not in description.

## 5. Ads Policy Violation
REASON: Full-screen interstitial ads shown too frequently or blocking
     content. Ads shown to children without complying with COPPA.
FIX: Limit interstitial frequency (no more than every 2 screens).
     Never show ads that prevent closing for 5+ seconds.

## 6. Impersonation / Intellectual Property
REASON: App icon, name, or content mimics another app or brand.
FIX: Use original branding. Do not reference competitor names.

## 7. User Data Policy - No Deletion Mechanism
REASON: App collects personal data but provides no way to delete it.
FIX: Implement in-app account deletion and link a data deletion
     URL in Play Console. Must delete data within 60 days.

## 8. Subscription Transparency
REASON: Subscription terms not clearly disclosed before purchase.
FIX: Show price, billing period, trial length, and cancellation
     instructions on the subscription screen BEFORE purchase button.

## 9. Use of Restricted Permissions
REASON: Requesting SMS, call log, or location permissions without
     justification. Using ACCESS_FINE_LOCATION without core feature need.
FIX: Request only permissions your core functionality requires.
     Submit a Permissions Declaration Form for sensitive permissions.

## 10. Background Location Access
REASON: Using ACCESS_BACKGROUND_LOCATION without core need.
FIX: Must submit Background Location Access approval form.
     Only approved for navigation, fitness tracking, family safety.

## 11. Misleading Store Listing
REASON: Screenshots, description, or title misrepresent the app.
FIX: Screenshots must show actual current app UI. Description
     must match current build functionality.

## 12. Broken Functionality
REASON: App crashes on launch or features described do not work.
FIX: Test on reference devices (Pixel 6+, Samsung Galaxy S22+)
     with latest stable Android version.

## 13. Minimum Functionality
REASON: App provides no meaningful utility beyond a web wrapper.
FIX: Add native features: offline support, push notifications,
     device integration (camera, sensors).

## 14. Content Rating Missing or Inaccurate
REASON: IARC questionnaire not completed or answers are inaccurate.
FIX: Complete the content rating questionnaire honestly. Update
     if content changes (e.g., adding user-generated content).

## 15. In-App Billing Policy Violation
REASON: Digital goods sold outside Google Play Billing.
FIX: Use Google Play Billing for all digital goods and subscriptions.
     Physical goods (Uber, DoorDash) and "reader" apps are exempt.

## 16. Families Policy Violation
REASON: App targets children but does not comply with Families policies.
FIX: If app targets children under 13, use only certified ad SDKs,
     no behavioral advertising, and comply with COPPA.

## 17. Spam / Repetitive Content
REASON: Multiple apps with same functionality or auto-generated content.
FIX: Consolidate into single app. Ensure unique value per listing.

## 18. Malicious Behavior (Dynamic Code Loading)
REASON: App loads executable code from sources other than Google Play.
FIX: Do not use DexClassLoader to load remote DEX files. OTA JS
     bundle updates (CodePush) are generally acceptable for RN/Flutter.

## 19. Crypto Mining
REASON: App runs cryptocurrency mining on device.
FIX: Remove all mining code. This is a permanent ban trigger.

## 20. Missing Government ID Verification (2024+)
REASON: Developer account not verified for new personal accounts.
FIX: Complete identity verification in Play Console settings
     before first app submission.
```

### Data Safety Form - Complete Guide

```markdown
## Data Safety Audit Process

Step 1: List ALL SDKs and libraries in your app
Step 2: For each SDK, identify what data it collects
Step 3: Map to Google's data type categories
Step 4: Fill the Data Safety form in Play Console

## Common SDK Data Collection Map

Firebase Analytics:
  - App interactions (collected, not shared)
  - Device or other IDs (collected, not shared)
  - Diagnostics / crash logs (collected, not shared)

Firebase Crashlytics:
  - Crash logs (collected, not shared)
  - Device or other IDs (collected, not shared)

Google AdMob:
  - Approximate location (collected AND shared)
  - Device or other IDs (collected AND shared)
  - Ad interactions (collected AND shared)

Facebook SDK (Login):
  - Name (collected, may be shared)
  - Email address (collected, may be shared)
  - User IDs (collected AND shared with Facebook)

Sentry:
  - Crash logs (collected, shared with Sentry)
  - Device info (collected, shared with Sentry)

Adjust / AppsFlyer:
  - Device or other IDs (collected AND shared)
  - App interactions (collected AND shared)
  - Purchase history (collected AND shared)

RevenueCat:
  - Purchase history (collected, shared with RevenueCat)
  - Device or other IDs (collected, shared with RevenueCat)

Supabase (self-hosted data):
  - Whatever YOU store: name, email, photos, etc.
  - Declare based on YOUR schema, not Supabase's infrastructure

## Data Safety Form Answers Structure

For each data type you must answer:
1. Is this data COLLECTED? (transmitted off device)
2. Is this data SHARED? (transferred to third parties)
3. Is this data PROCESSED ephemerally? (only in memory, never stored)
4. Is collection REQUIRED or can user opt out?
5. PURPOSE: App functionality / Analytics / Advertising / etc.
```

### Target API Level Migration

```groovy
// GOOD: build.gradle - meets current target API requirements
android {
    compileSdkVersion 35
    defaultConfig {
        applicationId "com.myapp"
        minSdkVersion 24        // Android 7.0 - covers 97%+ of devices
        targetSdkVersion 35     // Meets 2025 requirement
        versionCode 42
        versionName "2.1.0"
    }

    // Handle runtime permission changes in API 33+
    // API 33 requires POST_NOTIFICATIONS permission
    // API 34 requires FOREGROUND_SERVICE_* type permissions
}
```

```kotlin
// GOOD: Handle API 33+ notification permission requirement
import android.Manifest
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts

class MainActivity : ComponentActivity() {
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            // Set up push notification channels
            createNotificationChannels()
        } else {
            // Show in-app messaging instead of push
            showInAppNotificationFallback()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Only needed for API 33+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermissionLauncher.launch(
                Manifest.permission.POST_NOTIFICATIONS
            )
        }
    }
}
```

```xml
<!-- GOOD: AndroidManifest.xml - declare foreground service types (API 34+) -->
<manifest>
    <!-- API 34 requires declaring foreground service type -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    <service
        android:name=".LocationTrackingService"
        android:foregroundServiceType="location"
        android:exported="false" />

    <!-- Declare data deletion URL for Play Console -->
    <!-- This is referenced in Play Console store listing settings -->
</manifest>
```

### Content Rating Questionnaire Guide

```markdown
## IARC Content Rating - Key Questions

Violence:
- Does the app contain any violence? (Even cartoon violence counts)
- Is violence directed at characters or realistic humans?
- Answer YES if your app has: games with combat, news with violent content

Sexuality:
- Does the app contain sexual content or nudity?
- Answer YES if: dating app, content with suggestive themes

Language:
- Does the app contain profanity or crude humor?
- Consider user-generated content - if users can post, answer YES

Controlled Substances:
- References to drugs, alcohol, or tobacco?
- Answer YES if: alcohol delivery, cannabis-related, bar finder

User-Generated Content / Social:
- Can users communicate or share content?
- Answer YES if: chat, comments, photo sharing, forums
- Triggers requirement for: content moderation, reporting, blocking

Location Sharing:
- Can users share their location with other users?
- Answer YES if: real-time location sharing with friends/family

Digital Purchases:
- Does the app allow digital purchases?
- Answer YES if: in-app purchases, subscriptions

NOTE: Inaccurate answers can trigger re-rating or suspension.
      When in doubt, rate MORE restrictively.
```

### In-App Billing Compliance

```kotlin
// GOOD: Google Play Billing implementation with required disclosures
class SubscriptionActivity : ComponentActivity() {
    private lateinit var billingClient: BillingClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        billingClient = BillingClient.newBuilder(this)
            .setListener(purchasesUpdatedListener)
            .enablePendingPurchases()
            .build()

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    querySubscriptions()
                }
            }
            override fun onBillingServiceDisconnected() {
                // Retry connection
            }
        })
    }

    // Required: Show clear pricing before purchase
    private fun showSubscriptionDetails(productDetails: ProductDetails) {
        val offer = productDetails.subscriptionOfferDetails?.firstOrNull()
        val pricing = offer?.pricingPhases?.pricingPhaseList

        // Display to user:
        // - Price per period (e.g., "$9.99/month")
        // - Free trial duration if applicable
        // - What happens after trial ends
        // - How to cancel (link to Play Store subscriptions)
        // - Link to privacy policy and terms of service
    }
}
```

### Account Deletion Implementation (Required 2024+)

```typescript
// GOOD: React Native - in-app account deletion flow
function AccountDeletionScreen() {
  const [confirmText, setConfirmText] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDeleteAccount = async () => {
    if (confirmText !== 'DELETE') return;
    setIsDeleting(true);

    try {
      // 1. Delete user data from your backend
      await api.post('/account/delete', { userId: auth.userId });

      // 2. Revoke auth tokens
      await auth.signOut();

      // 3. Navigate to confirmation
      navigation.reset({ index: 0, routes: [{ name: 'AccountDeleted' }] });
    } catch (error) {
      Alert.alert('Error', 'Failed to delete account. Please contact support.');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Delete Account</Text>
      <Text style={styles.warning}>
        This will permanently delete your account and all associated data
        within 60 days. This action cannot be undone.
      </Text>
      <Text style={styles.instruction}>Type DELETE to confirm:</Text>
      <TextInput
        value={confirmText}
        onChangeText={setConfirmText}
        style={styles.input}
        autoCapitalize="characters"
      />
      <Button
        title={isDeleting ? 'Deleting...' : 'Delete My Account'}
        onPress={handleDeleteAccount}
        disabled={confirmText !== 'DELETE' || isDeleting}
        color="#D32F2F"
      />
      <Text style={styles.supportText}>
        If you need help, contact support@myapp.com
      </Text>
    </View>
  );
}
```

## Why This Works

- **Data Safety enforcement is automated**: Google scans manifests for declared permissions and SDK signatures. Mismatches between declared data collection and detected SDKs trigger automatic suspension notices.
- **Target API requirements are hard deadlines**: Google will block app updates (not just warn) if targetSdkVersion is below the required level. New permission models in each API level (e.g., POST_NOTIFICATIONS in 33, FOREGROUND_SERVICE types in 34) require code changes, not just a version bump.
- **Account deletion is legally required**: GDPR (EU), CCPA (California), and Google Play policy all mandate that users can request data deletion. Google requires the deletion URL to be registered in Play Console.
- **Billing policy violations can terminate your developer account**: Using external payment for digital goods is treated as a severe policy violation with potential account-level consequences.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**Android 14 (API 34):**
- `FOREGROUND_SERVICE` permission alone is no longer sufficient. You must also declare the specific type: `FOREGROUND_SERVICE_LOCATION`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, etc.
- Photo picker changes: `READ_MEDIA_IMAGES` replaces `READ_EXTERNAL_STORAGE`

**Android 15 (API 35):**
- Edge-to-edge display enforcement: apps must handle system bar insets correctly
- Foreground service restrictions tightened further

### Common Mistakes

- **Bumping targetSdkVersion without testing** - each API level introduces behavioral changes. API 33's photo picker, API 34's foreground service types, and API 35's edge-to-edge all require code changes.
- **Declaring "no data collected" while using Firebase** - Firebase Analytics alone collects device IDs and app interactions. If Firebase is in your dependencies, you collect data.
- **Not providing a web-accessible data deletion URL** - Play Console requires a URL that users can visit even if the app is uninstalled. An in-app-only deletion flow is insufficient.
- **Using alternative billing without being eligible** - only apps in eligible regions with approved alternative billing programs may use non-Google payment processors. Most apps must use Google Play Billing exclusively.
- **Submitting without completing content rating** - incomplete IARC questionnaire blocks publication entirely.

## Verification

```bash
# Check current targetSdkVersion
grep -r "targetSdkVersion\|targetSdk" android/app/build.gradle

# Verify no deprecated permissions
grep -r "READ_EXTERNAL_STORAGE\|WRITE_EXTERNAL_STORAGE" android/app/src/main/AndroidManifest.xml

# List all permissions declared
aapt dump permissions android/app/build/outputs/apk/release/app-release.apk

# Check for potential policy issues in APK
bundletool validate --bundle=app.aab
```

- [ ] targetSdkVersion meets current Google requirement (34+ for 2024, 35+ for 2025)
- [ ] Data Safety form completed and matches actual SDK data collection
- [ ] Privacy policy URL is accessible and linked in Play Console AND in-app
- [ ] Account deletion flow implemented and deletion URL registered in Play Console
- [ ] Content rating questionnaire completed with accurate answers
- [ ] All subscriptions show price, period, trial terms, and cancellation instructions
- [ ] POST_NOTIFICATIONS permission handled for API 33+ devices
- [ ] Foreground service types declared for API 34+ if using foreground services
- [ ] No restricted permissions requested without Permissions Declaration Form

## References

- [Google Play Developer Policy Center](https://play.google.com/about/developer-content-policy/)
- [Data Safety Form Help](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Target API Level Requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [IARC Content Ratings](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Account Deletion Requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
