---
id: flutter-platform-channels
category: skill
tags: [method-channel, event-channel, pigeon, platform-specific]
capabilities:
  - MethodChannel for native calls
  - EventChannel for streams
  - Pigeon code generation
  - Platform-specific implementations
useWhen:
  - Calling native iOS/Android code from Flutter
  - Streaming data from native to Flutter
  - Creating type-safe platform channels
---

# Flutter Platform Channels

Communicating between Flutter and native iOS/Android code.

## MethodChannel

```dart
// Dart
class BatteryService {
  static const _channel = MethodChannel('com.myapp/battery');

  Future<int> getBatteryLevel() async {
    final level = await _channel.invokeMethod<int>('getBatteryLevel');
    return level ?? -1;
  }
}

// iOS (Swift)
let channel = FlutterMethodChannel(name: "com.myapp/battery", binaryMessenger: controller.binaryMessenger)
channel.setMethodCallHandler { call, result in
  if call.method == "getBatteryLevel" {
    result(UIDevice.current.batteryLevel * 100)
  } else {
    result(FlutterMethodNotImplemented)
  }
}

// Android (Kotlin)
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.myapp/battery")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "getBatteryLevel" -> {
        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
        result.success(batteryManager.getIntProperty(BATTERY_PROPERTY_CAPACITY))
      }
      else -> result.notImplemented()
    }
  }
```

## EventChannel (Streams)

```dart
// Dart
class LocationService {
  static const _channel = EventChannel('com.myapp/location');

  Stream<Location> get locationStream {
    return _channel.receiveBroadcastStream().map((data) =>
      Location(lat: data['lat'], lng: data['lng'])
    );
  }
}

// iOS (Swift)
class LocationStreamHandler: NSObject, FlutterStreamHandler {
  var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = eventSink
    startLocationUpdates()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopLocationUpdates()
    return nil
  }
}
```

## Pigeon (Code Generation)

```dart
// pigeon/messages.dart
@HostApi()
abstract class BatteryApi {
  int getBatteryLevel();
}

// Generate: flutter pub run pigeon --input pigeon/messages.dart

// Usage in Dart
final api = BatteryApi();
final level = await api.getBatteryLevel();
```

## Best Practices

- Use Pigeon for type-safe channels
- Handle errors on both sides
- Clean up event channels on dispose
- Test on both platforms
