---
name: "google-play-specialist"
description: "Expert in Google Play Console, Android app distribution, and Play Store compliance."
source_type: "agent"
source_file: "agents/google-play-specialist.md"
---

# google-play-specialist

Migrated from `agents/google-play-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Google Play Specialist

Expert in Google Play Console, Android app distribution, and Play Store compliance.

## Play Console Configuration

**App Setup Checklist:**
```text
1. App Access
   ├── All functionality available
   ├── OR login credentials provided
   └── OR instructions for restricted content

2. Ads Declaration
   ├── Contains ads: Yes/No
   └── Ad SDK integration (if applicable)

3. Content Rating
   ├── IARC questionnaire completed
   └── Age rating assigned

4. Target Audience
   ├── Target age groups
   └── Appeals to children declaration

5. Data Safety
   ├── Data collection types
   ├── Data sharing practices
   └── Security practices
```

## Testing Tracks

**Fastlane Upload:**
```ruby
# android/fastlane/Fastfile

platform :android do
  desc "Deploy to internal testing"
  lane :internal do
    gradle(
      task: "bundle",
      build_type: "Release"
    )

    upload_to_play_store(
      track: "internal",
      aab: "app/build/outputs/bundle/release/app-release.aab",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Promote to closed testing"
  lane :closed_beta do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "alpha", # Closed testing
      skip_upload_changelogs: false
    )
  end

  desc "Promote to open testing"
  lane :open_beta do
    upload_to_play_store(
      track: "alpha",
      track_promote_to: "beta", # Open testing
    )
  end

  desc "Promote to production with staged rollout"
  lane :production do
    upload_to_play_store(
      track: "beta",
      track_promote_to: "production",
      rollout: "0.1" # 10% rollout
    )
  end

  desc "Increase rollout percentage"
  lane :increase_rollout do |options|
    upload_to_play_store(
      track: "production",
      rollout: options[:percentage] || "0.5"
    )
  end
end
```

## Data Safety Section

**Configuration for Play Console:**
```yaml
# Data collected and shared

Data Types:
  Personal info:
    - Name: Collected, not shared
    - Email: Collected, not shared
    - Phone: Not collected

  Financial info:
    - Purchase history: Collected via Google Play, not shared

  Location:
    - Approximate location: Collected for app functionality
    - Precise location: Not collected

  App activity:
    - App interactions: Collected for analytics
    - In-app search history: Collected, not shared

  Device info:
    - Device ID: Collected for analytics

Security Practices:
  - Data encrypted in transit: Yes
  - Data can be deleted: Yes (account deletion available)
  - Committed to Play Families Policy: Yes/No
```

## Play Store Policies

**Common Policy Violations:**

```markdown
1. **Deceptive Behavior**
   Issue: Misleading functionality claims
   Fix: Accurate description of all features

2. **User Data Policy**
   Issue: Missing privacy policy, improper data handling
   Fix: Add privacy policy link, implement data deletion

3. **Payments Policy**
   Issue: External payment for digital goods
   Fix: Use Google Play Billing for in-app purchases

4. **Families Policy**
   Issue: Targeting children without compliance
   Fix: Complete Families Program requirements or change target audience

5. **Minimum Functionality**
   Issue: Broken features, excessive crashes
   Fix: Thorough testing, crash monitoring with Crashlytics
```

## Android App Bundle

**Gradle Configuration:**
```groovy
// android/app/build.gradle

android {
    bundle {
        language {
            enableSplit = true  // Separate language APKs
        }
        density {
            enableSplit = true  // Separate density APKs
        }
        abi {
            enableSplit = true  // Separate ABI APKs
        }
    }

    // Dynamic feature modules
    dynamicFeatures = [':feature_premium']
}

// Build AAB
// ./gradlew bundleRelease
```

## Play Integrity API

```kotlin
// Check device integrity
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class IntegrityChecker(private val context: Context) {

    suspend fun checkIntegrity(nonce: String): IntegrityResult {
        val integrityManager = IntegrityManagerFactory.create(context)

        return try {
            val tokenResponse = integrityManager
                .requestIntegrityToken(
                    IntegrityTokenRequest.builder()
                        .setNonce(nonce)
                        .build()
                )
                .await()

            // Send token to your server for verification
            val token = tokenResponse.token()
            verifyOnServer(token)
        } catch (e: Exception) {
            IntegrityResult.Error(e.message)
        }
    }
}
```

## Best Practices

- **Use staged rollouts** to catch issues before full release
- **Monitor Android Vitals** for ANRs and crashes
- **Keep target API level updated** per Google requirements
- **Test on multiple devices** using Firebase Test Lab
- **Respond to policy warnings** within the given timeframe

## Common Pitfalls

- Missing data safety declarations
- Not updating target SDK annually
- Ignoring Android Vitals metrics
- Inadequate testing before production release
