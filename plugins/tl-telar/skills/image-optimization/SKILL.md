---
name: "image-optimization"
description: "Optimizing image loading and caching in mobile apps."
source_type: "skill"
source_file: "skills/image-optimization.md"
---

# image-optimization

Migrated from `skills/image-optimization.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Image Optimization

Optimizing image loading and caching in mobile apps.

## React Native (FastImage)

```typescript
import FastImage from 'react-native-fast-image'

<FastImage
  source={{
    uri: imageUrl,
    priority: FastImage.priority.high,
    cache: FastImage.cacheControl.immutable,
  }}
  style={styles.image}
  resizeMode={FastImage.resizeMode.cover}
  onLoadStart={() => setLoading(true)}
  onLoadEnd={() => setLoading(false)}
/>

// Preload images
FastImage.preload([
  { uri: 'https://example.com/image1.jpg' },
  { uri: 'https://example.com/image2.jpg' },
])

// Clear cache
FastImage.clearMemoryCache()
FastImage.clearDiskCache()
```

## Progressive Loading

```typescript
function ProgressiveImage({ thumbnailUri, fullUri, style }) {
  const [loaded, setLoaded] = useState(false)

  return (
    <View style={style}>
      {/* Blurred thumbnail */}
      <FastImage
        source={{ uri: thumbnailUri }}
        style={[StyleSheet.absoluteFill, { opacity: loaded ? 0 : 1 }]}
        blurRadius={10}
      />
      {/* Full resolution */}
      <FastImage
        source={{ uri: fullUri }}
        style={StyleSheet.absoluteFill}
        onLoadEnd={() => setLoaded(true)}
      />
    </View>
  )
}
```

## Flutter (CachedNetworkImage)

```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  fadeInDuration: Duration(milliseconds: 300),
  memCacheWidth: 300, // Resize in memory
)

// Precache images
precacheImage(
  CachedNetworkImageProvider(url),
  context,
);
```

## Best Practices

- Use WebP format for smaller file sizes
- Implement placeholder/skeleton states
- Size images appropriately for display
- Preload images for better UX
