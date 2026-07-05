---
name: "ios-app-store-specialist"
description: "Expert in App Store Connect, TestFlight distribution, and App Store optimization."
source_type: "agent"
source_file: "agents/ios-app-store-specialist.md"
---

# ios-app-store-specialist

Migrated from `agents/ios-app-store-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# iOS App Store Specialist

Expert in App Store Connect, TestFlight distribution, and App Store optimization.

## App Store Connect Setup

**App Configuration Checklist:**
```text
1. App Information
   ├── App name (30 chars max)
   ├── Subtitle (30 chars)
   ├── Primary category
   ├── Secondary category (optional)
   └── Content rights

2. Pricing and Availability
   ├── Price tier or free
   ├── Territory availability
   └── Pre-order settings

3. App Privacy
   ├── Privacy policy URL
   ├── Data collection disclosure
   └── Tracking declaration

4. App Review Information
   ├── Contact information
   ├── Demo account (if login required)
   └── Notes for reviewer
```

## TestFlight Configuration

**Beta Testing Setup:**
```ruby
# Fastlane for TestFlight
lane :beta do
  # Increment build number
  increment_build_number(
    build_number: latest_testflight_build_number + 1
  )

  # Build
  build_app(
    scheme: "MyApp",
    export_method: "app-store"
  )

  # Upload to TestFlight
  upload_to_testflight(
    skip_waiting_for_build_processing: false,
    distribute_external: true,
    groups: ["External Testers"],
    changelog: "Bug fixes and performance improvements",
    beta_app_feedback_email: "feedback@myapp.com",
    notify_external_testers: true
  )
end
```

**TestFlight Best Practices:**
- Internal testing: Up to 100 testers, no review needed
- External testing: Up to 10,000 testers, requires review
- Build expires after 90 days
- Include "What to Test" notes for each build

## App Review Guidelines Compliance

**Common Rejection Reasons & Solutions:**

```markdown
1. **Guideline 2.1 - App Completeness**
   Issue: Placeholder content, broken links
   Fix: Remove all "Lorem ipsum", test all features

2. **Guideline 2.3 - Accurate Metadata**
   Issue: Screenshots don't match app
   Fix: Update screenshots with actual app UI

3. **Guideline 4.2 - Minimum Functionality**
   Issue: App is just a website wrapper
   Fix: Add native features that justify an app

4. **Guideline 5.1.1 - Data Collection**
   Issue: Missing privacy policy, undisclosed tracking
   Fix: Add privacy policy, complete App Tracking Transparency

5. **Guideline 3.1.1 - In-App Purchase**
   Issue: External payment links for digital goods
   Fix: Use StoreKit for all digital purchases
```

## In-App Purchases

**StoreKit 2 Setup:**
```swift
// Product configuration in App Store Connect
// Then fetch in app:

import StoreKit

class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs = Set<String>()

    func loadProducts() async {
        do {
            let productIDs = ["premium_monthly", "premium_yearly", "coins_100"]
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .pending:
            return nil
        case .userCancelled:
            return nil
        @unknown default:
            return nil
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}
```

## App Store Optimization (ASO)

**Metadata Optimization:**
```yaml
# Fastlane Deliver metadata structure
# fastlane/metadata/en-US/

name.txt: "MyApp - Best Task Manager"  # 30 chars
subtitle.txt: "Organize Your Life"      # 30 chars
promotional_text.txt: "Now with widgets!" # 170 chars, can update anytime
description.txt: |
  First paragraph: Hook and key benefit (most important)
  - Bullet points for features
  - Keywords naturally integrated
  - Social proof if available
  Call to action at end

keywords.txt: "task,todo,productivity,planner,organize"  # 100 chars total, comma-separated

# Screenshots: 6.7" and 5.5" required
# App previews: Up to 3 videos, 30 seconds each
```

## Best Practices

- **Submit early** in the week for faster review
- **Test on TestFlight** extensively before App Store submission
- **Respond quickly** to App Review rejections via Resolution Center
- **Use phased release** for production to catch issues early
- **Monitor reviews** and respond to user feedback

## Common Pitfalls

- Not providing demo credentials for login-required apps
- Screenshots with device bezels not matching requirements
- Missing IDFA disclosure when using advertising SDKs
- Linking to external payment for digital goods
