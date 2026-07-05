---
id: maps-integration
category: skill
tags: [maps, google-maps, mapbox, markers, geocoding]
capabilities:
  - Google Maps integration
  - MapBox setup
  - Markers and clustering
  - Custom map styling
useWhen:
  - Adding maps to app
  - Displaying location markers
  - Implementing custom map styles
---

# Maps Integration

Integrating maps into mobile applications.

## React Native Maps

```typescript
import MapView, { Marker, PROVIDER_GOOGLE } from 'react-native-maps'

function MapScreen() {
  const [region, setRegion] = useState({
    latitude: 37.78825,
    longitude: -122.4324,
    latitudeDelta: 0.0922,
    longitudeDelta: 0.0421,
  })

  return (
    <MapView
      provider={PROVIDER_GOOGLE}
      style={{ flex: 1 }}
      region={region}
      onRegionChangeComplete={setRegion}
      showsUserLocation
      showsMyLocationButton
    >
      <Marker
        coordinate={{ latitude: 37.78825, longitude: -122.4324 }}
        title="Marker Title"
        description="Marker Description"
      />
    </MapView>
  )
}
```

## Custom Markers

```typescript
import { Marker, Callout } from 'react-native-maps'

function CustomMarker({ place }) {
  return (
    <Marker coordinate={place.coordinate}>
      {/* Custom marker view */}
      <View style={styles.markerContainer}>
        <Image source={{ uri: place.icon }} style={styles.markerIcon} />
      </View>

      {/* Custom callout */}
      <Callout>
        <View style={styles.callout}>
          <Text style={styles.title}>{place.name}</Text>
          <Text>{place.address}</Text>
        </View>
      </Callout>
    </Marker>
  )
}
```

## Marker Clustering

```typescript
import { ClusteredMapView } from 'react-native-map-clustering'

function ClusteredMap({ markers }) {
  return (
    <ClusteredMapView
      style={{ flex: 1 }}
      data={markers}
      initialRegion={initialRegion}
      clusterColor="#00B386"
      clusterTextColor="#fff"
      radius={50}
      renderCluster={(cluster) => (
        <CustomCluster cluster={cluster} />
      )}
    />
  )
}
```

## Flutter Google Maps

### API key setup

Before any code runs, wire up API keys per platform. Both stores reject builds that bundle a key committed to the repo — inject via `--dart-define` or a git-ignored config file.

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${MAPS_API_KEY}" />
```

Pass via Gradle (`android/app/build.gradle`):

```gradle
manifestPlaceholders = [MAPS_API_KEY: System.getenv("MAPS_API_KEY") ?: ""]
```

**iOS** — `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

GMSServices.provideAPIKey(
  Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as! String
)
```

Add `MAPS_API_KEY` to `Info.plist` (reference an xcconfig value, not a literal). Restrict keys per bundle id / SHA-1 in Google Cloud Console.

### Map + camera + user location

```dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};

  static const _initial = CameraPosition(
    target: LatLng(37.78825, -122.4324),
    zoom: 14,
  );

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _initial,
      onMapCreated: _controller.complete,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: false,
      onTap: _addMarker,
    );
  }

  Future<void> _animateTo(LatLng target, {double zoom = 16}) async {
    final c = await _controller.future;
    await c.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: zoom, tilt: 30),
      ),
    );
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId('${position.latitude},${position.longitude}'),
        position: position,
        infoWindow: const InfoWindow(title: 'Marker'),
      ));
    });
  }
}
```

### Marker clustering

Use the `google_maps_cluster_manager` package for large marker sets. Define a `ClusterItem` type, hand items to a `ClusterManager`, and let it emit markers as zoom changes.

```dart
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';

class Place with ClusterItem {
  Place({required this.name, required LatLng position}) : _position = position;
  final String name;
  final LatLng _position;
  @override
  LatLng get location => _position;
}

late ClusterManager<Place> _clusterManager;
Set<Marker> _clusteredMarkers = {};

@override
void initState() {
  super.initState();
  _clusterManager = ClusterManager<Place>(
    places,
    (markers) => setState(() => _clusteredMarkers = markers),
    markerBuilder: _buildClusterMarker,
    levels: const [1, 4.25, 6.75, 10.5, 14.5, 16.5, 20.0],
  );
}

// Wire it up in GoogleMap:
// onMapCreated: (c) { _controller.complete(c); _clusterManager.setMapId(c.mapId); }
// onCameraMove: _clusterManager.onCameraMove
// onCameraIdle: _clusterManager.updateMap
// markers: _clusteredMarkers
```

### Custom styles

Generate a JSON style at [mapstyle.withgoogle.com](https://mapstyle.withgoogle.com), bundle under `assets/map_style.json`, and apply on map ready:

```dart
final style = await rootBundle.loadString('assets/map_style.json');
final c = await _controller.future;
await c.setMapStyle(style);
```

iOS-only: styles also require `GMSServices.provideAPIKey` to be called first.

## Geocoding

```typescript
import Geocoder from 'react-native-geocoding'

Geocoder.init('YOUR_GOOGLE_API_KEY')

// Address to coordinates
const { results } = await Geocoder.from('New York, NY')
const { lat, lng } = results[0].geometry.location

// Coordinates to address
const { results } = await Geocoder.from(37.78825, -122.4324)
const address = results[0].formatted_address
```

## Best Practices

- Use clustering for many markers
- Lazy load markers outside viewport
- Cache geocoding results
- Use appropriate zoom levels
