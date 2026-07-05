---
name: "mobile-ads-integration"
description: "Implementing ads with Google AdMob."
source_type: "skill"
source_file: "skills/mobile-ads-integration.md"
---

# mobile-ads-integration

Migrated from `skills/mobile-ads-integration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


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
