---
name: "android-signing"
description: "Managing Android app signing and keystores."
source_type: "skill"
source_file: "skills/android-signing.md"
---

# android-signing

Migrated from `skills/android-signing.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Android Signing

Managing Android app signing and keystores.

## Create Keystore

```bash
keytool -genkeypair \
  -v \
  -storetype PKCS12 \
  -keystore my-release-key.keystore \
  -alias my-key-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

## Gradle Signing Config

```groovy
// android/app/build.gradle
android {
    signingConfigs {
        release {
            storeFile file(MYAPP_RELEASE_STORE_FILE)
            storePassword MYAPP_RELEASE_STORE_PASSWORD
            keyAlias MYAPP_RELEASE_KEY_ALIAS
            keyPassword MYAPP_RELEASE_KEY_PASSWORD
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Secure Credentials

```properties
# android/gradle.properties (DO NOT commit)
MYAPP_RELEASE_STORE_FILE=my-release-key.keystore
MYAPP_RELEASE_KEY_ALIAS=my-key-alias
MYAPP_RELEASE_STORE_PASSWORD=*****
MYAPP_RELEASE_KEY_PASSWORD=*****
```

## Play App Signing

```markdown
Benefits:
- Google manages your app signing key
- Smaller APK/AAB downloads
- Key recovery if lost

Setup:
1. Generate upload key (separate from app signing key)
2. Upload AAB signed with upload key
3. Google re-signs with app signing key

# Export certificate for API integrations
keytool -exportcert -alias upload \
  -keystore upload.keystore \
  -file upload_cert.der
```

## CI/CD Signing

```yaml
# GitHub Actions
- name: Decode keystore
  run: |
    echo ${{ secrets.KEYSTORE_BASE64 }} | base64 -d > android/app/release.keystore

- name: Build Release
  env:
    MYAPP_RELEASE_STORE_FILE: release.keystore
    MYAPP_RELEASE_STORE_PASSWORD: ${{ secrets.STORE_PASSWORD }}
    MYAPP_RELEASE_KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    MYAPP_RELEASE_KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: cd android && ./gradlew assembleRelease
```

## Best Practices

- Use Play App Signing for production
- Never commit keystores to git
- Keep upload key backup secure
- Use environment variables for credentials
