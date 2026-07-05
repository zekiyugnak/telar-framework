---
id: in-app-purchases
category: skill
tags: [storekit, play-billing, subscriptions, consumables]
capabilities:
  - StoreKit 2 implementation
  - Google Play Billing
  - Subscription management
  - Receipt validation
useWhen:
  - Implementing in-app purchases
  - Adding subscriptions
  - Setting up payment validation
---

# In-App Purchases

Implementing in-app purchases for iOS and Android.

## React Native (react-native-iap)

```typescript
import * as IAP from 'react-native-iap'

const productIds = ['premium_monthly', 'premium_yearly', 'coins_100']

// Initialize
useEffect(() => {
  IAP.initConnection()
    .then(() => IAP.getProducts({ skus: productIds }))
    .then(setProducts)

  // Listen for purchases
  const purchaseListener = IAP.purchaseUpdatedListener(async (purchase) => {
    if (purchase.transactionReceipt) {
      // Validate receipt on your server
      await validateReceipt(purchase.transactionReceipt)

      // Finish transaction
      await IAP.finishTransaction({ purchase, isConsumable: false })
    }
  })

  return () => {
    purchaseListener.remove()
    IAP.endConnection()
  }
}, [])

// Make purchase
async function buyProduct(sku: string) {
  try {
    await IAP.requestPurchase({ sku })
  } catch (error) {
    if (error.code === 'E_USER_CANCELLED') {
      // User cancelled
    }
  }
}
```

## Subscription Handling

```typescript
// Check subscription status
async function checkSubscription() {
  const purchases = await IAP.getAvailablePurchases()

  const activeSub = purchases.find(p => {
    // Check if subscription is still valid
    const receipt = JSON.parse(p.transactionReceipt)
    return new Date(receipt.expirationDate) > new Date()
  })

  return !!activeSub
}

// Restore purchases
async function restorePurchases() {
  const purchases = await IAP.getAvailablePurchases()
  for (const purchase of purchases) {
    await validateAndGrantAccess(purchase)
  }
}
```

## Server-Side Validation

```typescript
// Your backend
async function validateAppleReceipt(receipt: string) {
  const response = await fetch(
    'https://buy.itunes.apple.com/verifyReceipt',
    {
      method: 'POST',
      body: JSON.stringify({
        'receipt-data': receipt,
        password: process.env.APP_STORE_SECRET,
      }),
    }
  )
  return response.json()
}

async function validateGooglePurchase(
  purchaseToken: string,
  productId: string
) {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  })

  const androidpublisher = google.androidpublisher('v3')
  return androidpublisher.purchases.subscriptions.get({
    packageName: 'com.yourapp',
    subscriptionId: productId,
    token: purchaseToken,
  })
}
```

## Best Practices

- Always validate receipts server-side
- Handle restore purchases properly
- Test with sandbox accounts
- Implement grace period handling
