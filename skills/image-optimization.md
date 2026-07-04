---
id: image-optimization
category: skill
tags: [images, caching, webp, lazy-loading, progressive]
capabilities:
  - Image caching strategies
  - Progressive loading
  - WebP optimization
  - Lazy loading implementation
useWhen:
  - Optimizing image loading
  - Reducing bandwidth usage
  - Implementing image caching
---

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
