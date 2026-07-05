---
name: "location-services"
description: "Location tracking and geofencing in mobile apps."
source_type: "skill"
source_file: "skills/location-services.md"
---

# location-services

Migrated from `skills/location-services.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Location Services

Location tracking and geofencing in mobile apps.

## React Native Location

```typescript
import * as Location from 'expo-location'

async function requestLocationPermission() {
  const { status: foreground } = await Location.requestForegroundPermissionsAsync()
  if (foreground !== 'granted') {
    return false
  }

  // For background location
  const { status: background } = await Location.requestBackgroundPermissionsAsync()
  return background === 'granted'
}

async function getCurrentLocation() {
  const location = await Location.getCurrentPositionAsync({
    accuracy: Location.Accuracy.High,
  })

  return {
    latitude: location.coords.latitude,
    longitude: location.coords.longitude,
  }
}
```

## Location Tracking

```typescript
function useLocationTracking() {
  const [location, setLocation] = useState(null)

  useEffect(() => {
    let subscription: Location.LocationSubscription

    ;(async () => {
      subscription = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.Balanced,
          timeInterval: 5000,
          distanceInterval: 10,
        },
        (newLocation) => {
          setLocation(newLocation.coords)
        }
      )
    })()

    return () => subscription?.remove()
  }, [])

  return location
}
```

## Background Location

```typescript
import * as TaskManager from 'expo-task-manager'
import * as Location from 'expo-location'

const LOCATION_TASK = 'background-location-task'

TaskManager.defineTask(LOCATION_TASK, ({ data, error }) => {
  if (error) return
  const { locations } = data as { locations: Location.LocationObject[] }
  // Send to server or store locally
  sendLocationToServer(locations[0])
})

async function startBackgroundTracking() {
  await Location.startLocationUpdatesAsync(LOCATION_TASK, {
    accuracy: Location.Accuracy.Balanced,
    timeInterval: 60000, // 1 minute
    distanceInterval: 100, // 100 meters
    foregroundService: {
      notificationTitle: 'Location tracking',
      notificationBody: 'Your location is being tracked',
    },
  })
}
```

## Geofencing

```typescript
import * as Location from 'expo-location'

const GEOFENCE_TASK = 'geofence-task'

TaskManager.defineTask(GEOFENCE_TASK, ({ data, error }) => {
  if (error) return
  const { eventType, region } = data
  if (eventType === Location.GeofencingEventType.Enter) {
    sendNotification(`Entered ${region.identifier}`)
  } else if (eventType === Location.GeofencingEventType.Exit) {
    sendNotification(`Left ${region.identifier}`)
  }
})

await Location.startGeofencingAsync(GEOFENCE_TASK, [
  {
    identifier: 'home',
    latitude: 37.78825,
    longitude: -122.4324,
    radius: 100, // meters
    notifyOnEnter: true,
    notifyOnExit: true,
  },
])
```

## Flutter Location

### Default: `geolocator`

`geolocator` is the default choice for Flutter location work. It exposes permission, service-status, one-shot, and stream APIs with typed accuracy levels and works without a Google Play Services dependency on bare Android.

```dart
import 'package:geolocator/geolocator.dart';

Future<Position> getCurrentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services disabled');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Open settings to grant location');
  }

  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

Stream<Position> watchPosition() => Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.balanced,
        distanceFilter: 10,
      ),
    );
```

### When to pick `location` instead

The `location` package is a lighter alternative that exposes a `Location()` instance with `onLocationChanged`, `changeSettings`, and a built-in background-mode toggle on Android. Consider it when:

- You want background updates on Android without writing a foreground service (`enableBackgroundMode(enable: true)` handles the notification)
- You need a simpler stream API and don't need geolocator's distance/bearing helpers
- You're keeping Google Play Services as a hard dependency anyway

Keep `geolocator` as the default unless one of the above applies. Do not mix both in the same app — their permission state machines diverge.

```dart
import 'package:location/location.dart';

final location = Location();

Future<LocationData?> getOnce() async {
  if (!await location.serviceEnabled() && !await location.requestService()) {
    return null;
  }
  var status = await location.hasPermission();
  if (status == PermissionStatus.denied) {
    status = await location.requestPermission();
    if (status != PermissionStatus.granted) return null;
  }
  await location.changeSettings(accuracy: LocationAccuracy.high);
  return location.getLocation();
}
```

## Best Practices

- Request permissions with explanation
- Use appropriate accuracy levels
- Minimize background tracking for battery
- Handle permission denial gracefully
- Pick one Flutter package per app (`geolocator` *or* `location`) — not both
