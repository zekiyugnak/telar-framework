# iOS Code Signing Guide

Complete walkthrough for iOS code signing and provisioning.

## Concepts

### Certificates
- **Development Certificate**: Signs apps for running on your devices during development
- **Distribution Certificate**: Signs apps for App Store or Ad Hoc distribution
- **Apple Push Certificate**: Required for push notifications
- Each team can have limited distribution certificates (3 per type)

### Provisioning Profiles
- **Development**: Links dev certificate + app ID + device UDIDs
- **Ad Hoc**: Links distribution certificate + app ID + specific device UDIDs (up to 100)
- **App Store**: Links distribution certificate + app ID (no device list)
- **Enterprise**: For internal distribution (requires Enterprise account)

### App IDs
- **Explicit**: `com.company.appname` (required for most capabilities)
- **Wildcard**: `com.company.*` (limited capabilities, useful for development)

## Manual Setup

### 1. Create Certificate

```bash
# Generate Certificate Signing Request (CSR)
# Keychain Access → Certificate Assistant → Request a Certificate From a CA
# Save to disk as CertificateSigningRequest.certSigningRequest

# Upload CSR to Apple Developer Portal
# Certificates, Identifiers & Profiles → Certificates → Create
# Select: Apple Distribution
# Upload CSR file
# Download .cer file and double-click to install in Keychain
```

### 2. Register App ID

```
Apple Developer Portal → Identifiers → Register
- Platform: iOS
- Description: My App
- Bundle ID: Explicit → com.company.myapp
- Enable capabilities: Push Notifications, Sign in with Apple, etc.
```

### 3. Register Devices (for Development/Ad Hoc)

```
Apple Developer Portal → Devices → Register
- Name: iPhone 15 Pro
- UDID: (get from Xcode → Window → Devices and Simulators)
```

### 4. Create Provisioning Profile

```
Apple Developer Portal → Profiles → Generate
- Type: App Store (for submission)
- App ID: com.company.myapp
- Certificate: Select your distribution certificate
- Download and double-click to install
```

## Fastlane Match (Recommended)

Fastlane Match stores certificates and profiles in a Git repo or cloud storage for team sharing.

### Initial Setup

```bash
# Install Fastlane
brew install fastlane

# Initialize Match
cd ios
fastlane match init

# Choose storage:
# 1. git (private repo)
# 2. google_cloud
# 3. s3
```

### Matchfile Configuration

```ruby
# ios/fastlane/Matchfile
git_url("https://github.com/company/certificates.git")
storage_mode("git")
type("appstore")
app_identifier(["com.company.myapp"])
username("developer@company.com")
team_id("XXXXXXXXXX")
```

### Generate Certificates & Profiles

```bash
# Development
fastlane match development

# Ad Hoc (for TestFlight alternatives)
fastlane match adhoc

# App Store Distribution
fastlane match appstore

# Force regenerate (if expired/revoked)
fastlane match appstore --force
```

### CI/CD Usage

```ruby
# Fastfile
lane :build do
  setup_ci if ENV['CI']

  match(
    type: "appstore",
    readonly: true,  # Don't create new certs on CI
    keychain_name: "fastlane_tmp_keychain",
    keychain_password: ""
  )

  build_app(
    scheme: "MyApp",
    export_method: "app-store"
  )
end
```

### Environment Variables for CI

```bash
MATCH_GIT_URL=https://github.com/company/certificates.git
MATCH_PASSWORD=<encryption-password>
MATCH_KEYCHAIN_NAME=fastlane_tmp_keychain
MATCH_KEYCHAIN_PASSWORD=""
FASTLANE_USER=developer@company.com
FASTLANE_TEAM_ID=XXXXXXXXXX
```

## Expo EAS Build

EAS manages code signing automatically.

```bash
# Configure signing
eas credentials

# Or let EAS manage automatically
eas build --platform ios --profile production
# EAS will prompt to generate/select credentials
```

### eas.json Signing Config

```json
{
  "build": {
    "production": {
      "ios": {
        "distribution": "store",
        "autoIncrement": true,
        "credentialsSource": "remote"
      }
    }
  }
}
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| "No signing certificate" | Certificate not in Keychain | Download and install from Developer Portal |
| "Provisioning profile doesn't include signing certificate" | Mismatch | Regenerate profile with correct certificate |
| "Device not included" | UDID not in profile | Add device, regenerate profile |
| "Code signing entitlements error" | Capability mismatch | Verify App ID capabilities match entitlements |
| "Certificate has expired" | Annual renewal needed | Create new certificate, regenerate profiles |
| "Maximum number of certificates" | 3 cert limit reached | Revoke unused certs or use Match |
