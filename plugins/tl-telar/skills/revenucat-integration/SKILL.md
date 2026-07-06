---
name: "revenucat-integration"
description: "Subscription management with RevenueCat."
source_type: "skill"
source_file: "skills/revenucat-integration.md"
---

# revenucat-integration

Migrated from `skills/revenucat-integration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# RevenueCat Integration

Subscription management with RevenueCat.

## React Native Setup

```typescript
import Purchases, { LOG_LEVEL } from 'react-native-purchases'

// Initialize on app start
Purchases.setLogLevel(LOG_LEVEL.DEBUG)

if (Platform.OS === 'ios') {
  await Purchases.configure({ apiKey: 'appl_xxx' })
} else {
  await Purchases.configure({ apiKey: 'goog_xxx' })
}

// Identify user (after login)
await Purchases.logIn(userId)
```

## Check Entitlements

```typescript
async function checkPremiumAccess() {
  const customerInfo = await Purchases.getCustomerInfo()
  return customerInfo.entitlements.active['premium'] !== undefined
}

// Hook for entitlements
function usePremium() {
  const [isPremium, setIsPremium] = useState(false)

  useEffect(() => {
    Purchases.addCustomerInfoUpdateListener((info) => {
      setIsPremium(info.entitlements.active['premium'] !== undefined)
    })

    checkPremiumAccess().then(setIsPremium)
  }, [])

  return isPremium
}
```

## Fetch Offerings & Purchase

```typescript
async function getOfferings() {
  const offerings = await Purchases.getOfferings()
  if (offerings.current) {
    return offerings.current.availablePackages
  }
  return []
}

async function purchase(pkg: PurchasesPackage) {
  try {
    const { customerInfo } = await Purchases.purchasePackage(pkg)
    if (customerInfo.entitlements.active['premium']) {
      // User is now premium
      return true
    }
  } catch (error) {
    if (!error.userCancelled) {
      console.error('Purchase error:', error)
    }
  }
  return false
}

// Restore purchases
async function restore() {
  const customerInfo = await Purchases.restorePurchases()
  return customerInfo.entitlements.active['premium'] !== undefined
}
```

## Paywall Component

```typescript
function Paywall() {
  const [packages, setPackages] = useState([])

  useEffect(() => {
    getOfferings().then(setPackages)
  }, [])

  return (
    <View>
      {packages.map(pkg => (
        <TouchableOpacity key={pkg.identifier} onPress={() => purchase(pkg)}>
          <Text>{pkg.product.title}</Text>
          <Text>{pkg.product.priceString}/month</Text>
        </TouchableOpacity>
      ))}
    </View>
  )
}
```

## Best Practices

- Use entitlements, not product IDs
- Set up webhooks for server sync
- Configure offerings in dashboard
- Track subscription events for analytics
