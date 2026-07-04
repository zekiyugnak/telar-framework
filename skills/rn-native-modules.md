---
id: rn-native-modules
category: skill
tags: [native-modules, swift, kotlin, bridging, turbomodules]
capabilities:
  - Creating native modules for iOS (Swift)
  - Creating native modules for Android (Kotlin)
  - Bridging native code to JavaScript
  - TurboModules basics
useWhen:
  - Accessing native APIs not available in React Native
  - Creating custom native functionality
  - Bridging third-party native SDKs
---

# React Native Native Modules

Creating native modules to bridge iOS and Android code to React Native.

## iOS Native Module (Swift)

```swift
// CalendarModule.swift
@objc(CalendarModule)
class CalendarModule: NSObject {

  @objc
  func createEvent(
    _ title: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    // Native implementation
    let eventId = UUID().uuidString
    resolve(["eventId": eventId])
  }

  @objc
  static func requiresMainQueueSetup() -> Bool {
    return false
  }
}

// CalendarModule.m (Bridging)
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(CalendarModule, NSObject)
RCT_EXTERN_METHOD(createEvent:(NSString *)title
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
@end
```

## Android Native Module (Kotlin)

```kotlin
// CalendarModule.kt
class CalendarModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

  override fun getName() = "CalendarModule"

  @ReactMethod
  fun createEvent(title: String, promise: Promise) {
    try {
      val eventId = UUID.randomUUID().toString()
      promise.resolve(WritableNativeMap().apply {
        putString("eventId", eventId)
      })
    } catch (e: Exception) {
      promise.reject("ERROR", e.message)
    }
  }
}

// CalendarPackage.kt
class CalendarPackage : ReactPackage {
  override fun createNativeModules(reactContext: ReactApplicationContext) =
    listOf(CalendarModule(reactContext))

  override fun createViewManagers(reactContext: ReactApplicationContext) = emptyList()
}
```

## JavaScript Usage

```typescript
import { NativeModules } from 'react-native'

const { CalendarModule } = NativeModules

interface CalendarModuleInterface {
  createEvent(title: string): Promise<{ eventId: string }>
}

export const Calendar = CalendarModule as CalendarModuleInterface

// Usage
const result = await Calendar.createEvent('Meeting')
console.log(result.eventId)
```

## Best Practices

- Always use promises for async operations
- Handle errors on both native and JS sides
- Use `requiresMainQueueSetup` appropriately
- Register packages in MainApplication (Android)
