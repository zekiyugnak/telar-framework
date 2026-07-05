---
name: "flutter-audio"
description: "Audio playback in Flutter with `just_audio` as the default. For media recording (microphone capture), see `flutter-device-plugins`."
source_type: "skill"
source_file: "skills/flutter-audio.md"
---

# flutter-audio

Migrated from `skills/flutter-audio.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Flutter Audio

Audio playback in Flutter with `just_audio` as the default. For media recording (microphone capture), see `flutter-device-plugins`.

## Package choice

| Use case | Package |
|---|---|
| General playback (music, podcasts, sound effects) | `just_audio` |
| Background + lock-screen controls + CarPlay / Android Auto | `just_audio` + `audio_service` |
| Simple one-shot UI sounds | `just_audio` (or `audioplayers` if bundle size matters) |
| Recording audio | `record` package |
| Low-latency game audio | `soloud` |

`just_audio` is the default. It supports streaming, playlists, ReplayGain, gapless, pitch/speed — and pairs cleanly with `audio_service` for background.

Do not use the legacy `audioplayers` for new work unless you have a specific bundle-size reason. It lacks playlist handling and has weaker background support.

## Basic playback

```dart
import 'package:just_audio/just_audio.dart';

class AudioController {
  final _player = AudioPlayer();

  Future<void> load(String url) async {
    await _player.setUrl(url);
  }

  void play() => _player.play();
  void pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> dispose() => _player.dispose();

  Stream<Duration> get position => _player.positionStream;
  Stream<PlayerState> get state => _player.playerStateStream;
  Stream<Duration?> get duration => _player.durationStream;
}
```

`play()` returns a `Future` that completes when playback finishes — do not `await` it unless you want to block. Call without `await` for fire-and-forget playback.

## Platform setup

### iOS — background audio capability

Enable **Audio, AirPlay, and Picture in Picture** in Xcode → Runner → Signing & Capabilities → Background Modes. In `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

Without this, audio stops the moment the app backgrounds.

### Android — foreground service for background playback

Background playback needs a foreground service (user sees a persistent notification). Use `audio_service` (below) — it handles the service declaration. If you only need in-foreground playback, no manifest changes are required.

For HTTP streams on Android, allow cleartext if the audio URL is not HTTPS:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
    android:usesCleartextTraffic="true"
    ... >
```

Prefer HTTPS — production audio URLs should always be TLS.

## Playlists

```dart
final playlist = ConcatenatingAudioSource(
  useLazyPreparation: true, // don't preload every track
  shuffleOrder: DefaultShuffleOrder(),
  children: [
    AudioSource.uri(Uri.parse('https://example.com/track1.mp3'),
        tag: MediaItem(id: '1', title: 'Track 1')),
    AudioSource.uri(Uri.parse('https://example.com/track2.mp3'),
        tag: MediaItem(id: '2', title: 'Track 2')),
  ],
);

await _player.setAudioSource(playlist, initialIndex: 0);
_player.setLoopMode(LoopMode.all);
_player.setShuffleModeEnabled(false);

// Navigate
await _player.seekToNext();
await _player.seekToPrevious();
```

`useLazyPreparation: true` is important for large playlists — without it every track's header is fetched on `setAudioSource`.

## Background playback with `audio_service`

`audio_service` wraps `just_audio` with the Android foreground service and iOS `MPRemoteCommandCenter` wiring. Users see a lock-screen widget with play/pause/next/previous.

```yaml
dependencies:
  just_audio: ^0.9.40
  audio_service: ^0.18.16
```

```dart
// Register once in main()
Future<void> main() async {
  final handler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.myapp.audio',
      androidNotificationChannelName: 'Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(MyApp(handler: handler));
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> loadEpisode(String url, MediaItem item) async {
    mediaItem.add(item);
    await _player.setUrl(url);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
```

Declare the service in `android/app/src/main/AndroidManifest.xml`:

```xml
<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true"
    tools:ignore="Instantiatable">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
    </intent-filter>
</service>

<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</receiver>
```

## Interruption handling

Audio apps must respond to phone calls, other media apps, and headphone unplugs. `just_audio` surfaces interruptions via `AudioSession`:

```dart
import 'package:audio_session/audio_session.dart';

final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.music());

session.interruptionEventStream.listen((event) {
  if (event.begin) {
    _player.pause(); // another app took focus
  } else if (event.type == AudioInterruptionType.pause) {
    _player.play(); // resume when appropriate
  }
});

session.becomingNoisyEventStream.listen((_) {
  // Headphones unplugged — pause so audio doesn't blare from speaker
  _player.pause();
});
```

`becomingNoisy` (headphone unplug) is not optional for music/podcast apps — users expect auto-pause.

## Streaming and caching

`just_audio` streams by default from `AudioSource.uri`. For caching use `just_audio_cache` or a `LockCachingAudioSource`:

```dart
import 'package:just_audio/just_audio.dart';

final source = LockCachingAudioSource(
  Uri.parse('https://example.com/podcast.mp3'),
);
await _player.setAudioSource(source);
```

This streams the file, caches bytes to the app's temporary dir, and replays from the cache on subsequent plays. Clear the cache periodically — podcast apps can accumulate GBs otherwise.

## Testing

`AudioPlayer` is not straightforward to mock because it's backed by a platform channel. Wrap it behind a port:

```dart
abstract class AudioPort {
  Future<void> load(String url);
  void play();
  void pause();
  Stream<Duration> get position;
}

class JustAudioAdapter implements AudioPort {
  final _player = AudioPlayer();
  @override
  Future<void> load(String url) => _player.setUrl(url);
  @override
  void play() => _player.play();
  @override
  void pause() => _player.pause();
  @override
  Stream<Duration> get position => _player.positionStream;
}

class FakeAudio implements AudioPort {
  final _positionController = StreamController<Duration>.broadcast();
  @override
  Future<void> load(String url) async {}
  @override
  void play() {}
  @override
  void pause() {}
  @override
  Stream<Duration> get position => _positionController.stream;
}
```

Test the state machine (e.g., "when load succeeds, track is ready") against the fake. Reserve real-device smoke tests for actual playback verification.

## Best Practices

- **Pick `just_audio`** as the default — pair with `audio_service` only when you need background + lock-screen controls
- **Enable the iOS audio background mode** even if you're not sure you'll use it — cheap to add, expensive to discover missing in production
- **Always call `_player.dispose()`** when leaving the screen to free the native resource
- **Handle `becomingNoisy`** for any music/podcast UX — users expect auto-pause on unplug
- **Use `LockCachingAudioSource` for long-form audio** to avoid re-download on replay
- **Wrap `AudioPlayer` behind an interface** for testability

## Common Pitfalls

- **Audio stops when screen locks** — missing `UIBackgroundModes.audio` in iOS Info.plist
- **Foreground-service crash on Android 14+** — missing `android:foregroundServiceType="mediaPlayback"` on the service declaration
- **Playlist `setAudioSource` hangs for a minute** — forgot `useLazyPreparation: true` on a large `ConcatenatingAudioSource`
- **Audio plays over phone call** — didn't subscribe to `interruptionEventStream`
- **Memory leak** — `AudioPlayer` not disposed when the page closes
- **Cleartext audio URL blocked on Android 9+** — set `usesCleartextTraffic` or (better) serve HTTPS
- **`just_audio` + `audioplayers` both in the app** — can conflict over the audio session; pick one
