---
id: android-signing
category: skill
tags: [keystore, signing-config, play-app-signing, gradle]
capabilities:
  - Keystore management
  - Signing configuration
  - Play App Signing setup
  - Gradle signing config
useWhen:
  - Setting up Android signing
  - Managing keystores
  - Configuring Play App Signing
---

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
