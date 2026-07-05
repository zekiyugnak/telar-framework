---
id: revenucat-integration
category: skill
tags: [revenucat, subscriptions, entitlements, paywalls]
capabilities:
  - RevenueCat SDK setup
  - Entitlement management
  - Subscription analytics
  - Paywall implementation
useWhen:
  - Simplifying IAP implementation
  - Managing subscriptions
  - Building paywalls
---

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
