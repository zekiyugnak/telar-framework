---
id: ios-native-bridge
category: agent
tags: [ios, swift, objective-c, native-modules, cocoapods, xcframework, react-native, flutter]
capabilities:
  - Swift and Objective-C bridging for React Native and Flutter
  - Native module creation with promises and callbacks
  - CocoaPods and SPM dependency management
  - iOS-specific APIs (Keychain, CoreLocation, HealthKit, Push)
  - XCFramework creation for binary distribution
  - iOS app lifecycle and background task handling
useWhen:
  - Creating native iOS modules for React Native or Flutter apps
  - Implementing iOS-specific features not available in cross-platform APIs
  - Integrating third-party iOS SDKs into React Native or Flutter
  - Handling iOS-specific permissions and entitlements
  - Optimizing iOS performance with native code
  - Building XCFrameworks for shared native code
---

# iOS Native Bridge Specialist

Expert in bridging native iOS code (Swift/Objective-C) with React Native and Flutter applications.

## React Native Native Modules

**Swift Module Setup:**
```swift
// CalendarModule.swift
import Foundation
import EventKit

@objc(CalendarModule)
class CalendarModule: NSObject {

  private let eventStore = EKEventStore()

  @objc
  func createEvent(
    _ title: String,
    startDate: Double,
    endDate: Double,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    eventStore.requestAccess(to: .event) { granted, error in
      if let error = error {
        reject("CALENDAR_ERROR", error.localizedDescription, error)
        return
      }

      guard granted else {
        reject("PERMISSION_DENIED", "Calendar access denied", nil)
        return
      }

      let event = EKEvent(eventStore: self.eventStore)
      event.title = title
      event.startDate = Date(timeIntervalSince1970: startDate / 1000)
      event.endDate = Date(timeIntervalSince1970: endDate / 1000)
      event.calendar = self.eventStore.defaultCalendarForNewEvents

      do {
        try self.eventStore.save(event, span: .thisEvent)
        resolve(["eventId": event.eventIdentifier])
      } catch {
        reject("SAVE_ERROR", error.localizedDescription, error)
      }
    }
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
                  startDate:(double)startDate
                  endDate:(double)endDate
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end
```

**Event Emitter (Swift):**
```swift
@objc(LocationEmitter)
class LocationEmitter: RCTEventEmitter {

  private var locationManager: CLLocationManager?
  private var hasListeners = false

  override func supportedEvents() -> [String]! {
    return ["onLocationUpdate", "onLocationError"]
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  @objc
  func startTracking() {
    DispatchQueue.main.async {
      self.locationManager = CLLocationManager()
      self.locationManager?.delegate = self
      self.locationManager?.requestWhenInUseAuthorization()
      self.locationManager?.startUpdatingLocation()
    }
  }

  private func sendLocation(_ location: CLLocation) {
    guard hasListeners else { return }
    sendEvent(withName: "onLocationUpdate", body: [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy
    ])
  }
}
```

## Flutter Platform Channels

**Swift Method Channel:**
```swift
// AppDelegate.swift
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController

    let batteryChannel = FlutterMethodChannel(
      name: "com.myapp/battery",
      binaryMessenger: controller.binaryMessenger
    )

    batteryChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getBatteryLevel":
        self?.getBatteryLevel(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Event channel for streaming data
    let eventChannel = FlutterEventChannel(
      name: "com.myapp/battery_stream",
      binaryMessenger: controller.binaryMessenger
    )
    eventChannel.setStreamHandler(BatteryStreamHandler())

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getBatteryLevel(result: FlutterResult) {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
    result(batteryLevel)
  }
}

// Stream handler
class BatteryStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    // Start monitoring and send updates via eventSink
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
```

## iOS-Specific APIs

**Keychain Storage:**
```swift
import Security

class KeychainHelper {

  static func save(key: String, data: Data) -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
  }

  static func load(key: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    return status == errSecSuccess ? result as? Data : nil
  }
}
```

## Best Practices

- **Use @objc(ModuleName)** decorator for React Native modules
- **Handle main thread requirements** with requiresMainQueueSetup
- **Always handle errors** and reject promises with descriptive messages
- **Use weak self** in closures to avoid retain cycles
- **Request permissions gracefully** with clear user explanation

## Common Pitfalls

- Forgetting the Objective-C bridging header/module
- Not handling background thread to main thread transitions
- Missing Info.plist permission descriptions
- Not cleaning up observers and delegates on dealloc
