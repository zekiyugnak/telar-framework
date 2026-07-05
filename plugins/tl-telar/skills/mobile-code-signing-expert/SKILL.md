---
name: "mobile-code-signing-expert"
description: "Expert in mobile app code signing for iOS and Android platforms."
source_type: "agent"
source_file: "agents/mobile-code-signing-expert.md"
---

# mobile-code-signing-expert

Migrated from `agents/mobile-code-signing-expert.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile Code Signing Expert

Expert in mobile app code signing for iOS and Android platforms.

## iOS Code Signing

**Certificate Types:**
```yaml
Development:
├── iOS Development - Local testing on devices
└── Apple Development - Universal (recommended)

Distribution:
├── iOS Distribution - App Store and Ad Hoc
├── Apple Distribution - Universal (recommended)
└── Developer ID - macOS outside App Store
```

**Provisioning Profiles:**
```yaml
Development:
├── iOS App Development - Testing on registered devices

Distribution:
├── App Store - App Store submission
├── Ad Hoc - Limited distribution (100 devices)
└── Enterprise - In-house distribution (requires Enterprise account)
```

## Fastlane Match

**Setup:**
```ruby
# Matchfile
git_url("git@github.com:company/certificates.git")
storage_mode("git")  # or "s3", "google_cloud"

type("appstore")  # development, adhoc, appstore, enterprise
app_identifier(["com.myapp", "com.myapp.widget"])

# For CI
readonly(true)  # Prevent creating new certificates in CI
```

**Usage:**
```ruby
# Fastfile
lane :sync_certs do
  # Development certificates
  match(type: "development", readonly: true)

  # App Store certificates
  match(type: "appstore", readonly: true)
end

lane :build_release do
  match(type: "appstore", readonly: true)

  build_app(
    scheme: "MyApp",
    export_method: "app-store"
  )
end
```

**Initial Setup:**
```bash
# Create certificates and profiles
fastlane match development
fastlane match appstore

# Nuke and recreate (if certificates expire)
fastlane match nuke development
fastlane match nuke distribution
```

## iOS Entitlements

**Common Capabilities:**
```xml
<!-- MyApp.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <!-- Push Notifications -->
    <key>aps-environment</key>
    <string>production</string>

    <!-- App Groups (for extensions) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.myapp</string>
    </array>

    <!-- Keychain Sharing -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.myapp</string>
    </array>

    <!-- Associated Domains (Universal Links) -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:myapp.com</string>
        <string>webcredentials:myapp.com</string>
    </array>

    <!-- Sign in with Apple -->
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

## Android Keystore

**Create Keystore:**
```bash
# Generate release keystore
keytool -genkeypair -v \
  -keystore release.keystore \
  -alias my-key-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass your_store_password \
  -keypass your_key_password \
  -dname "CN=My App, OU=Mobile, O=My Company, L=City, ST=State, C=US"

# View keystore info
keytool -list -v -keystore release.keystore
```

**Gradle Configuration:**
```groovy
// android/app/build.gradle
android {
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
        release {
            if (System.getenv("CI")) {
                storeFile file(System.getenv("KEYSTORE_PATH"))
                storePassword System.getenv("KEYSTORE_PASSWORD")
                keyAlias System.getenv("KEY_ALIAS")
                keyPassword System.getenv("KEY_PASSWORD")
            } else {
                // Local properties file
                def props = new Properties()
                props.load(new FileInputStream(file("keystore.properties")))
                storeFile file(props['storeFile'])
                storePassword props['storePassword']
                keyAlias props['keyAlias']
                keyPassword props['keyPassword']
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## Play App Signing

```markdown
Benefits:
- Google manages your app signing key
- Smaller APK downloads (optimized delivery)
- Key recovery if lost

Setup:
1. Go to Play Console > Setup > App signing
2. Choose "Let Google manage and protect your app signing key"
3. Upload your existing keystore OR let Google generate one
4. Download upload key certificate for verification
```

## CI/CD Code Signing

**GitHub Actions (iOS):**
```yaml
- name: Install certificates
  env:
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_AUTH }}
  run: |
    bundle exec fastlane match appstore --readonly
```

**GitHub Actions (Android):**
```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/release.keystore

- name: Build release
  env:
    KEYSTORE_PATH: release.keystore
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: cd android && ./gradlew bundleRelease
```

## Best Practices

- **Never commit keystores/certificates** to source control
- **Use Match** for team certificate management
- **Backup keystores securely** - loss means new app listing
- **Rotate keys periodically** for security
- **Use separate keystores** for debug and release

## Common Pitfalls

- Losing the release keystore (cannot update app)
- Certificate expiration without renewal plan
- Mismatched provisioning profiles and entitlements
- Not enrolling in Play App Signing early
