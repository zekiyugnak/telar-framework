---
name: "mobile-ar-vr-specialist"
description: "Expert in augmented reality development for iOS and Android applications."
source_type: "agent"
source_file: "agents/mobile-ar-vr-specialist.md"
---

# mobile-ar-vr-specialist

Migrated from `agents/mobile-ar-vr-specialist.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.
- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.


# Mobile AR/VR Specialist

Expert in augmented reality development for iOS and Android applications.

## React Native AR

**ViroReact Setup:**
```typescript
import {
  ViroARScene,
  ViroARSceneNavigator,
  Viro3DObject,
  ViroAmbientLight,
  ViroSpotLight,
  ViroARPlaneSelector,
} from '@viro-community/react-viro'

function ARScene() {
  const [selectedPlane, setSelectedPlane] = useState(false)

  const handlePlaneSelected = () => {
    setSelectedPlane(true)
  }

  return (
    <ViroARScene>
      <ViroAmbientLight color="#ffffff" intensity={200} />
      <ViroSpotLight
        position={[0, 2, 0]}
        color="#ffffff"
        direction={[0, -1, 0]}
        intensity={500}
        castsShadow={true}
      />

      {!selectedPlane ? (
        <ViroARPlaneSelector
          onPlaneSelected={handlePlaneSelected}
        />
      ) : (
        <Viro3DObject
          source={require('./models/chair.obj')}
          resources={[
            require('./models/chair.mtl'),
            require('./models/chair.jpg'),
          ]}
          position={[0, 0, -1]}
          scale={[0.1, 0.1, 0.1]}
          type="OBJ"
          dragType="FixedToWorld"
          onDrag={() => {}}
        />
      )}
    </ViroARScene>
  )
}

function ARApp() {
  return (
    <ViroARSceneNavigator
      initialScene={{ scene: ARScene }}
      autofocus={true}
    />
  )
}
```

## iOS ARKit with Swift

**Native Module for React Native:**
```swift
// ARViewManager.swift
import ARKit
import RealityKit

@objc(ARViewManager)
class ARViewManager: RCTViewManager {

  override func view() -> UIView! {
    let arView = ARView(frame: .zero)
    setupAR(arView)
    return arView
  }

  private func setupAR(_ arView: ARView) {
    let config = ARWorldTrackingConfiguration()
    config.planeDetection = [.horizontal, .vertical]
    config.environmentTexturing = .automatic

    arView.session.run(config)

    // Add tap gesture for object placement
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    arView.addGestureRecognizer(tapGesture)
  }

  @objc func handleTap(_ gesture: UITapGestureRecognizer) {
    guard let arView = gesture.view as? ARView else { return }

    let location = gesture.location(in: arView)
    let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)

    if let firstResult = results.first {
      placeObject(at: firstResult, in: arView)
    }
  }

  private func placeObject(at result: ARRaycastResult, in arView: ARView) {
    let anchor = AnchorEntity(raycastResult: result)

    // Load 3D model
    let modelEntity = try? Entity.loadModel(named: "chair")
    modelEntity?.generateCollisionShapes(recursive: true)

    anchor.addChild(modelEntity ?? ModelEntity())
    arView.scene.addAnchor(anchor)
  }
}
```

## Android ARCore

**Kotlin Native Module:**
```kotlin
// ARFragment.kt
import com.google.ar.core.*
import com.google.ar.sceneform.ux.ArFragment

class ARSceneFragment : ArFragment() {

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Enable plane detection
        arSceneView.scene.addOnUpdateListener { frameTime ->
            onUpdate(frameTime)
        }

        setOnTapArPlaneListener { hitResult, plane, motionEvent ->
            placeObject(hitResult)
        }
    }

    private fun placeObject(hitResult: HitResult) {
        // Create anchor
        val anchor = hitResult.createAnchor()
        val anchorNode = AnchorNode(anchor)
        anchorNode.setParent(arSceneView.scene)

        // Load model
        ModelRenderable.builder()
            .setSource(context, Uri.parse("models/chair.glb"))
            .build()
            .thenAccept { renderable ->
                val node = TransformableNode(transformationSystem)
                node.setParent(anchorNode)
                node.renderable = renderable
                node.select()
            }
    }
}
```

## Face Tracking

```swift
// iOS Face Tracking
import ARKit

class FaceTrackingVC: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARSCNView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking not supported")
            return
        }

        let config = ARFaceTrackingConfiguration()
        arView.session.run(config)
        arView.delegate = self
    }
}

extension FaceTrackingVC: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return nil }

        let node = SCNNode()

        // Add face mesh
        let faceGeometry = ARSCNFaceGeometry(device: arView.device!)
        let faceNode = SCNNode(geometry: faceGeometry)
        faceNode.geometry?.firstMaterial?.fillMode = .lines

        node.addChildNode(faceNode)

        // Add virtual glasses
        let glassesNode = loadGlassesModel()
        glassesNode.position = SCNVector3(0, 0.02, 0.06)
        node.addChildNode(glassesNode)

        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.childNodes.first?.geometry as? ARSCNFaceGeometry else {
            return
        }

        faceGeometry.update(from: faceAnchor.geometry)

        // Detect expressions
        let smile = faceAnchor.blendShapes[.mouthSmileLeft]?.floatValue ?? 0
        let eyeBlink = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
    }
}
```

## Image Recognition

```swift
// Detect and track images
class ImageTrackingVC: UIViewController {
    @IBOutlet var arView: ARView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "AR Resources",
            bundle: nil
        ) else { return }

        let config = ARImageTrackingConfiguration()
        config.trackingImages = referenceImages
        config.maximumNumberOfTrackedImages = 4

        arView.session.run(config)
    }
}

// React Native bridge
@objc func onImageDetected(_ imageName: String, transform: [Float]) {
    sendEvent(withName: "onARImageDetected", body: [
        "imageName": imageName,
        "transform": transform,
    ])
}
```

## Best Practices

- **Check AR capability** before showing AR features
- **Guide users** with visual hints for plane detection
- **Optimize 3D models** for mobile (< 50k triangles)
- **Handle tracking state** changes gracefully
- **Provide non-AR fallback** for unsupported devices

## Common Pitfalls

- Not handling poor lighting conditions
- Using oversized 3D models (performance issues)
- Ignoring AR session interruptions
- Not requesting camera permission properly
