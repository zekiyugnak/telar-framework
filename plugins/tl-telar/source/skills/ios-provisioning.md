---
id: ios-provisioning
category: skill
tags: [certificates, provisioning-profiles, entitlements, fastlane-match]
capabilities:
  - Certificate management
  - Provisioning profile setup
  - Entitlements configuration
  - Fastlane Match automation
useWhen:
  - Setting up iOS code signing
  - Managing certificates
  - Automating provisioning
---

# iOS Provisioning

Managing iOS certificates, profiles, and entitlements.

## Certificate Types

```markdown
Development:
- iOS Development Certificate
- Used for debug builds
- Per-developer

Distribution:
- iOS Distribution Certificate (App Store)
- Apple Distribution Certificate (universal)
- Team-wide, limited to 3
```

## Provisioning Profiles

```markdown
Development Profile:
- Ties app ID + dev certificates + devices
- Used for local testing

App Store Profile:
- Ties app ID + distribution certificate
- No device list needed

Ad Hoc Profile:
- For testing on specific devices
- Up to 100 devices per year
```

## Fastlane Match

```ruby
# Matchfile
git_url("https://github.com/org/certificates.git")
storage_mode("git")
type("appstore") # or development, adhoc

app_identifier(["com.app.main", "com.app.main.widget"])
username("apple@email.com")
team_id("TEAM_ID")

# Generate/sync certificates
# fastlane match appstore
# fastlane match development
```

## CI/CD Usage

```yaml
# GitHub Actions
- name: Install certificates
  env:
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_AUTH }}
  run: |
    fastlane match appstore --readonly

# Fastfile
lane :build do
  match(type: "appstore", readonly: true)
  build_app(scheme: "MyApp")
end
```

## Entitlements

```xml
<!-- MyApp.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>production</string>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:example.com</string>
    </array>
</dict>
</plist>
```

## Best Practices

- Use Fastlane Match for team certificate sharing
- Store certificates in encrypted git repo
- Use readonly mode in CI to prevent overwrites
- Rotate certificates before expiration
