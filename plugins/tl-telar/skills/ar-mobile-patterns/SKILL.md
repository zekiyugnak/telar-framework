---
name: "ar-mobile-patterns"
description: "Augmented reality patterns for mobile apps."
source_type: "skill"
source_file: "skills/ar-mobile-patterns.md"
---

# ar-mobile-patterns

Migrated from `skills/ar-mobile-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# AR Mobile Patterns

Augmented reality patterns for mobile apps.

## React Native AR (ViroReact)

```typescript
import {
  ViroARScene,
  ViroARSceneNavigator,
  ViroBox,
  ViroMaterials,
  ViroAmbientLight,
} from '@viro-community/react-viro'

ViroMaterials.createMaterials({
  wood: {
    diffuseTexture: require('./res/wood.jpg'),
  },
})

function ARScene() {
  const [position, setPosition] = useState([0, 0, -1])

  return (
    <ViroARScene>
      <ViroAmbientLight color="#ffffff" />
      <ViroBox
        position={position}
        scale={[0.3, 0.3, 0.3]}
        materials={['wood']}
        dragType="FixedDistance"
        onDrag={(pos) => setPosition(pos)}
      />
    </ViroARScene>
  )
}

function App() {
  return (
    <ViroARSceneNavigator
      autofocus
      initialScene={{ scene: ARScene }}
      style={{ flex: 1 }}
    />
  )
}
```

## Plane Detection

```typescript
import { ViroARPlane, ViroQuad } from '@viro-community/react-viro'

function ARScene() {
  const [planes, setPlanes] = useState([])

  return (
    <ViroARScene>
      <ViroARPlane
        minHeight={0.1}
        minWidth={0.1}
        alignment="Horizontal"
        onAnchorFound={(anchor) => {
          setPlanes(prev => [...prev, anchor])
        }}
      >
        <ViroQuad
          rotation={[-90, 0, 0]}
          scale={[0.5, 0.5, 1]}
          materials={['grid']}
        />
      </ViroARPlane>
    </ViroARScene>
  )
}
```

## Image Tracking

```typescript
import { ViroARImageMarker, ViroARTrackingTargets } from '@viro-community/react-viro'

ViroARTrackingTargets.createTargets({
  logo: {
    source: require('./res/logo.png'),
    orientation: 'Up',
    physicalWidth: 0.1, // meters
  },
})

function ARScene() {
  return (
    <ViroARScene>
      <ViroARImageMarker target="logo">
        {/* Content appears when logo is detected */}
        <ViroText
          text="Logo detected!"
          position={[0, 0.1, 0]}
          style={{ fontSize: 20 }}
        />
      </ViroARImageMarker>
    </ViroARScene>
  )
}
```

## Flutter AR (ARCore/ARKit)

```dart
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';

class ARScreen extends StatefulWidget {
  @override
  _ARScreenState createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;

  @override
  Widget build(BuildContext context) {
    return ARView(
      onARViewCreated: onARViewCreated,
      planeDetectionConfig: PlaneDetectionConfig.horizontal,
    );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isNotEmpty) {
      final hit = hits.first;
      // Add 3D object at tap location
      await arObjectManager!.addNode(
        ARNode(
          type: NodeType.localGLTF2,
          uri: 'assets/model.glb',
          position: hit.pose.translation,
          scale: Vector3(0.1, 0.1, 0.1),
        ),
      );
    }
  }
}
```

## Best Practices

- Test on physical devices only
- Optimize 3D models for mobile
- Provide clear user guidance
- Handle tracking loss gracefully
