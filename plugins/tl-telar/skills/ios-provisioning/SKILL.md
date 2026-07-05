---
name: "ios-provisioning"
description: "Managing iOS certificates, profiles, and entitlements."
source_type: "skill"
source_file: "skills/ios-provisioning.md"
---

# ios-provisioning

Migrated from `skills/ios-provisioning.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
