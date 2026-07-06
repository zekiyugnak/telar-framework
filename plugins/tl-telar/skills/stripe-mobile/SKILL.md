---
name: "stripe-mobile"
description: "Payment processing with Stripe SDK."
source_type: "skill"
source_file: "skills/stripe-mobile.md"
---

# stripe-mobile

Migrated from `skills/stripe-mobile.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Stripe Mobile

Payment processing with Stripe SDK.

## React Native Setup

```typescript
import { StripeProvider } from '@stripe/stripe-react-native'

function App() {
  return (
    <StripeProvider
      publishableKey="pk_xxx"
      merchantIdentifier="merchant.com.yourapp"
      urlScheme="yourapp"
    >
      <Navigation />
    </StripeProvider>
  )
}
```

## Payment Sheet

```typescript
import { useStripe } from '@stripe/stripe-react-native'

function Checkout() {
  const { initPaymentSheet, presentPaymentSheet } = useStripe()

  async function checkout(amount: number) {
    // 1. Get payment intent from your server
    const { clientSecret, ephemeralKey, customerId } = await fetch(
      '/api/create-payment-intent',
      {
        method: 'POST',
        body: JSON.stringify({ amount }),
      }
    ).then(r => r.json())

    // 2. Initialize payment sheet
    const { error: initError } = await initPaymentSheet({
      merchantDisplayName: 'Your App',
      paymentIntentClientSecret: clientSecret,
      customerEphemeralKeySecret: ephemeralKey,
      customerId,
      applePay: { merchantCountryCode: 'US' },
      googlePay: { merchantCountryCode: 'US', testEnv: __DEV__ },
    })

    if (initError) return

    // 3. Present payment sheet
    const { error } = await presentPaymentSheet()

    if (error) {
      Alert.alert('Payment failed', error.message)
    } else {
      Alert.alert('Success', 'Payment completed!')
    }
  }
}
```

## Apple Pay Direct

```typescript
import { useApplePay } from '@stripe/stripe-react-native'

function ApplePayButton() {
  const { isApplePaySupported, presentApplePay, confirmApplePayPayment } =
    useApplePay()

  async function pay() {
    const { error } = await presentApplePay({
      cartItems: [{ label: 'Total', amount: '50.00' }],
      country: 'US',
      currency: 'USD',
    })

    if (error) return

    // Get client secret from server
    const { clientSecret } = await createPaymentIntent()

    await confirmApplePayPayment(clientSecret)
  }

  if (!isApplePaySupported) return null

  return <ApplePayButton onPress={pay} />
}
```

## Server-Side (Node.js)

```typescript
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY)

app.post('/create-payment-intent', async (req, res) => {
  const { amount, customerId } = req.body

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customerId },
    { apiVersion: '2023-10-16' }
  )

  const paymentIntent = await stripe.paymentIntents.create({
    amount: amount * 100, // cents
    currency: 'usd',
    customer: customerId,
  })

  res.json({
    clientSecret: paymentIntent.client_secret,
    ephemeralKey: ephemeralKey.secret,
    customerId,
  })
})
```

## Best Practices

- Create PaymentIntents server-side
- Enable Apple Pay/Google Pay for faster checkout
- Handle 3D Secure authentication
- Test with Stripe test cards
