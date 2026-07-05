# Store Compliance Adversarial Rubric

## Purpose

Used by the conditional Adversarial Store Compliance Reviewer, activated when WU file scope touches release config or `/tl-telar:release-app` is the operating context. Adversarial (not collaborative) because store policy violations directly cause rejection; a soft "needs revision" is too lenient.

## Reviewer mode

**Adversarial.** Binary PASS/FAIL. Fresh `Task()` instance.

## Evaluation criteria

### ST. Store policy failures

A WU FAILS store-compliance review if any of:

**App Store (Apple):**

- ST1. New `Info.plist` permission key (NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription, etc.) without a user-facing explanation string.
- ST2. In-app purchase flow that doesn't route through StoreKit (digital goods MUST use IAP per Apple guidelines).
- ST3. External payment link for digital goods (App Store rejection magnet).
- ST4. Background mode declared in capabilities without a documented background task justifying it.
- ST5. New tracking SDK introduced without ATTrackingManager prompt + privacy nutrition label update.
- ST6. WebView with `javaScriptEnabled` AND remote URLs, in a context that could be deemed "duplicate of web app" (App Store rejection risk per guideline 4.2).

**Play Store (Google):**

- ST7. New runtime permission requested without rationale prompt prior to system dialog.
- ST8. Background location access without prominent disclosure UX shown before first request.
- ST9. SDK known to violate Play policy (e.g., ad SDK with COPPA issues, payment SDK competing with Google Play Billing for digital goods).
- ST10. `targetSdkVersion` below the Play Store current minimum (constantly increasing — verify against current Play requirements at review time).

**Cross-platform:**

- ST11. App icon or screenshots updated without checking against current store guidelines (size, alpha channel, text overlays).
- ST12. Privacy policy URL missing or pointing to a 404 when store metadata references it.
- ST13. Age rating disclosed in store metadata doesn't match content (e.g., chat feature added but age rating still 4+).

## Verdict format

JSON per the sub-spec 1 verdict schema. Rule IDs ST1-ST13. Reviewer field: `"store-compliance"`.
