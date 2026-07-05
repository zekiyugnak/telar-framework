---
name: "flutter-device-plugins"
description: "Device-access plugins every non-trivial Flutter app needs: `image_picker`, `file_picker`, `share_plus`, and the common companions. For audio capture/playback see the `flutter-audio` skill. For location see `location-serv"
source_type: "skill"
source_file: "skills/flutter-device-plugins.md"
---

# flutter-device-plugins

Migrated from `skills/flutter-device-plugins.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Device Plugins

Device-access plugins every non-trivial Flutter app needs: `image_picker`, `file_picker`, `share_plus`, and the common companions. For audio capture/playback see the `flutter-audio` skill. For location see `location-services`.

## image_picker

The default choice for camera + photo-library selection. Works on iOS, Android, macOS, and web with one API.

```yaml
# pubspec.yaml
dependencies:
  image_picker: ^1.1.2
```

### iOS — Info.plist keys

Required or the app **crashes on launch** when the picker opens:

```xml
<!-- ios/Runner/Info.plist -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to let you upload an avatar.</string>
<key>NSCameraUsageDescription</key>
<string>We need camera access to take a profile photo.</string>
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access when recording video.</string>
```

App Store reviewers reject vague strings like "camera access" — describe the user-facing feature.

### Android — no permissions needed on modern versions

For Android 13+ the system photo picker runs in a separate process and needs **no** `READ_MEDIA_IMAGES` permission. `image_picker` uses it automatically. For camera capture, declare the feature (not the permission):

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

Do not add `READ_EXTERNAL_STORAGE` — it triggers Play Console warnings and is unnecessary.

### Usage

```dart
import 'package:image_picker/image_picker.dart';

class AvatarPickerController {
  final _picker = ImagePicker();

  Future<XFile?> pickFromGallery() => _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

  Future<XFile?> takePhoto() => _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        imageQuality: 85,
      );

  Future<List<XFile>> pickMultiple() => _picker.pickMultiImage(
        maxWidth: 2048,
        imageQuality: 85,
      );
}
```

**Always set `maxWidth`/`maxHeight`/`imageQuality`.** The default returns full-resolution originals — a single 12MP camera photo is ~5MB and will OOM a list of thumbnails.

### Cropping

Pair with `image_cropper` for profile flows:

```dart
import 'package:image_cropper/image_cropper.dart';

Future<CroppedFile?> cropAvatar(String path) => ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Crop', lockAspectRatio: true),
        IOSUiSettings(title: 'Crop', aspectRatioLockEnabled: true),
      ],
    );
```

### Handling cancellation

`pickImage` returns `null` when the user cancels. Do not throw — show no UI change.

```dart
final file = await picker.pickFromGallery();
if (file == null) return;
await uploadAvatar(File(file.path));
```

## file_picker — non-image documents

For PDFs, text, or arbitrary files use `file_picker`. It handles iOS document-picker UI, Android Storage Access Framework, and returns both path and bytes.

```dart
import 'package:file_picker/file_picker.dart';

final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf', 'docx'],
  allowMultiple: false,
);
if (result == null) return;
final file = File(result.files.single.path!);
```

On iOS, set `NSDocumentsFolderUsageDescription` in `Info.plist` if you open documents from the Files app.

## share_plus — outbound sharing

`share_plus` wraps iOS `UIActivityViewController` and Android `Intent.ACTION_SEND`.

```dart
import 'package:share_plus/share_plus.dart';

// Text + URL
await Share.share(
  'Check out this article: $url',
  subject: 'Interesting read',
);

// Files
await Share.shareXFiles(
  [XFile(imagePath)],
  text: 'My receipt',
);
```

iPad: pass `sharePositionOrigin` so the popover anchors to the button rect, or the share sheet crashes:

```dart
final box = context.findRenderObject() as RenderBox?;
await Share.share(
  text,
  sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
);
```

## url_launcher — outbound URLs and `tel:` / `mailto:`

```dart
import 'package:url_launcher/url_launcher.dart';

await launchUrl(
  Uri.parse('https://example.com'),
  mode: LaunchMode.externalApplication,
);
```

For `tel:`, `sms:`, and `mailto:` add `LSApplicationQueriesSchemes` on iOS:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>tel</string>
  <string>mailto</string>
  <string>sms</string>
</array>
```

## Testing

Inject an abstraction for each plugin behind a port so tests can swap in a fake. `ImagePicker` is a class you can mock directly, but wrapping it is cleaner when you need to inject multiple device plugins.

```dart
abstract class MediaPicker {
  Future<XFile?> pickImage({required ImageSource source});
}

class ImagePickerAdapter implements MediaPicker {
  final _picker = ImagePicker();
  @override
  Future<XFile?> pickImage({required ImageSource source}) =>
      _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
}

class FakeMediaPicker implements MediaPicker {
  XFile? result;
  @override
  Future<XFile?> pickImage({required ImageSource source}) async => result;
}
```

## Best Practices

- **Always cap image size** (`maxWidth`, `maxHeight`, `imageQuality`) — never ship full-res
- **Declare Info.plist usage strings** or iOS crashes before showing the picker
- **Prefer Android 13+ photo picker** over legacy file permissions — no permission prompt needed
- **Return null, don't throw, on user cancel** — cancellation is expected, not an error
- **Pass `sharePositionOrigin` on iPad** for `share_plus` — omitting it crashes on popover-required devices
- **Wrap in an adapter interface** when multiple features need device access, so tests can inject fakes

## Common Pitfalls

- Missing `NSCameraUsageDescription` — App Store reject or runtime crash
- Not capping `imageQuality` — OOM crashes on low-memory devices with long lists
- Adding `READ_EXTERNAL_STORAGE` on Android 13+ — Play Console policy warning
- Not handling `null` return from `pickImage` — treating cancel as an error
- iPad share-sheet missing `sharePositionOrigin` — crash on first share
- Relying on `XFile.path` on web — use `XFile.readAsBytes()` for cross-platform code
