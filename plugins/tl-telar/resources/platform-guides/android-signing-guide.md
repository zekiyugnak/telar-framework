# Android Code Signing Guide

Complete walkthrough for Android app signing and Play App Signing.

## Concepts

### Key Types
- **Upload Key**: Used to sign APK/AAB before uploading to Play Console
- **App Signing Key**: Google's key used to sign the final APK delivered to users
- **Debug Key**: Auto-generated for development builds (`~/.android/debug.keystore`)

### Play App Signing
Google manages the app signing key. You sign with your upload key, Google re-signs with the app signing key. Benefits:
- Key recovery if upload key is lost
- Smaller APKs via App Bundle optimization
- Key rotation without re-publishing

## Generate Upload Keystore

```bash
# Generate new keystore
keytool -genkeypair \
  -v \
  -storetype PKCS12 \
  -keystore my-upload-key.keystore \
  -alias my-key-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

# You'll be prompted for:
# - Keystore password
# - Key password
# - Name, Organization, City, State, Country
```

**IMPORTANT:** Store the keystore file and passwords securely. Loss = inability to update the app.

## Configure Gradle Signing

### Option 1: gradle.properties (local only)

```properties
# android/gradle.properties (DO NOT commit to git)
MYAPP_UPLOAD_STORE_FILE=my-upload-key.keystore
MYAPP_UPLOAD_KEY_ALIAS=my-key-alias
MYAPP_UPLOAD_STORE_PASSWORD=your-store-password
MYAPP_UPLOAD_KEY_PASSWORD=your-key-password
```

### Option 2: Environment Variables (CI/CD)

```groovy
// android/app/build.gradle
android {
    signingConfigs {
        release {
            if (project.hasProperty('MYAPP_UPLOAD_STORE_FILE')) {
                storeFile file(MYAPP_UPLOAD_STORE_FILE)
                storePassword MYAPP_UPLOAD_STORE_PASSWORD
                keyAlias MYAPP_UPLOAD_KEY_ALIAS
                keyPassword MYAPP_UPLOAD_KEY_PASSWORD
            }
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Enroll in Play App Signing

### New App
1. Create app in Play Console
2. Play App Signing is automatically enabled
3. Upload your first AAB signed with your upload key
4. Google generates and manages the app signing key

### Existing App
1. Play Console → Setup → App signing
2. Export existing key: `keytool -export -rfc -keystore existing.keystore -alias key-alias -file upload_certificate.pem`
3. Upload the key to Google
4. Google wraps your existing key as the app signing key
5. Generate a new upload key for future uploads

## Build Signed AAB

```bash
# React Native
cd android
./gradlew bundleRelease
# Output: android/app/build/outputs/bundle/release/app-release.aab

# Flutter
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab

# Verify signing
jarsigner -verify -verbose -certs app-release.aab
```

## Fastlane for Android

```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  lane :build do
    gradle(
      task: 'bundle',
      build_type: 'Release',
      properties: {
        "android.injected.signing.store.file" => ENV["KEYSTORE_PATH"],
        "android.injected.signing.store.password" => ENV["KEYSTORE_PASSWORD"],
        "android.injected.signing.key.alias" => ENV["KEY_ALIAS"],
        "android.injected.signing.key.password" => ENV["KEY_PASSWORD"],
      }
    )
  end

  lane :deploy do
    build
    upload_to_play_store(
      track: 'internal',
      aab: 'app/build/outputs/bundle/release/app-release.aab'
    )
  end
end
```

## EAS Build for Android

```bash
# Configure signing
eas credentials --platform android

# Or provide keystore
eas credentials --platform android
# Select: Upload Keystore
# Provide .keystore file and passwords
```

### eas.json

```json
{
  "build": {
    "production": {
      "android": {
        "buildType": "app-bundle",
        "autoIncrement": true,
        "credentialsSource": "remote"
      }
    }
  }
}
```

## CI/CD Environment Variables

```bash
# Base64-encode keystore for CI secrets
base64 -i my-upload-key.keystore -o keystore-base64.txt

# In CI, decode and use
echo "$KEYSTORE_BASE64" | base64 --decode > android/app/my-upload-key.keystore
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| "Keystore was tampered with" | Wrong password | Verify STORE_PASSWORD |
| "No key with alias found" | Wrong alias | Check KEY_ALIAS matches keytool output |
| "APK not signed" | Signing config not applied | Verify build.gradle signingConfig reference |
| "Version code already used" | versionCode not incremented | Increment versionCode |
| "Upload key doesn't match" | Different key than registered | Use original upload key or contact Google |
| "AAB size too large" | Resources not optimized | Enable shrinkResources, optimize images |
