---
id: mobile-ads-integration
category: skill
tags: [admob, ads, rewarded-ads, interstitials, banners]
capabilities:
  - AdMob integration
  - Rewarded ads
  - Interstitial ads
  - Banner ads
useWhen:
  - Adding ads to app
  - Implementing rewarded video
  - Monetizing with ads
---

# Mobile Ads Integration

Implementing ads with Google AdMob.

## React Native Setup

```typescript
import mobileAds, {
  MaxAdContentRating,
} from 'react-native-google-mobile-ads'

// Initialize on app start
mobileAds()
  .setRequestConfiguration({
    maxAdContentRating: MaxAdContentRating.PG,
    tagForChildDirectedTreatment: false,
    testDeviceIdentifiers: ['EMULATOR'],
  })
  .then(() => mobileAds().initialize())
```

## Banner Ads

```typescript
import { BannerAd, BannerAdSize, TestIds } from 'react-native-google-mobile-ads'

const adUnitId = __DEV__
  ? TestIds.BANNER
  : 'ca-app-pub-xxxxx/yyyyyy'

function AdBanner() {
  return (
    <BannerAd
      unitId={adUnitId}
      size={BannerAdSize.ANCHORED_ADAPTIVE_BANNER}
      requestOptions={{
        requestNonPersonalizedAdsOnly: true,
      }}
      onAdLoaded={() => console.log('Ad loaded')}
      onAdFailedToLoad={(error) => console.error(error)}
    />
  )
}
```

## Interstitial Ads

```typescript
import { InterstitialAd, AdEventType, TestIds } from 'react-native-google-mobile-ads'

const interstitial = InterstitialAd.createForAdRequest(
  __DEV__ ? TestIds.INTERSTITIAL : 'ca-app-pub-xxxxx/yyyyyy'
)

function useInterstitialAd() {
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const unsubLoaded = interstitial.addAdEventListener(
      AdEventType.LOADED,
      () => setLoaded(true)
    )
    const unsubClosed = interstitial.addAdEventListener(
      AdEventType.CLOSED,
      () => {
        setLoaded(false)
        interstitial.load() // Preload next
      }
    )

    interstitial.load()

    return () => {
      unsubLoaded()
      unsubClosed()
    }
  }, [])

  const show = () => {
    if (loaded) interstitial.show()
  }

  return { loaded, show }
}
```

## Rewarded Ads

```typescript
import { RewardedAd, RewardedAdEventType, TestIds } from 'react-native-google-mobile-ads'

const rewarded = RewardedAd.createForAdRequest(
  __DEV__ ? TestIds.REWARDED : 'ca-app-pub-xxxxx/yyyyyy'
)

function useRewardedAd(onReward: (amount: number) => void) {
  useEffect(() => {
    const unsubEarned = rewarded.addAdEventListener(
      RewardedAdEventType.EARNED_REWARD,
      (reward) => {
        onReward(reward.amount)
      }
    )

    rewarded.load()

    return () => unsubEarned()
  }, [])

  return {
    show: () => rewarded.loaded && rewarded.show(),
  }
}
```

## Best Practices

- Use test IDs during development
- Respect user's ad preferences
- Don't show interstitials too frequently
- Preload ads for better UX
