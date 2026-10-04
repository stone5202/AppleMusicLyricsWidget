# AppleMusicLyricsWidget

<p align="center">
  <a href="README.md">繁體中文</a> · <strong>English</strong>
</p>

Displays lyrics for the song currently playing in Apple Music on the iPhone Dynamic Island, Lock Screen, Home Screen widgets, and inside the app.

Current version: **1.0.0** (see [CHANGELOG.en.md](CHANGELOG.en.md); also available in [Traditional Chinese](CHANGELOG.md))

## Features

- **Live Activities**: Shows the current lyric line and the next two lines on the Dynamic Island and Lock Screen with centered layout. Lyrics continue updating after switching apps or locking the screen, and follow track changes.
- **Widgets**: Supports small and medium Home Screen widgets and the rectangular Lock Screen widget. The small widget can also appear in StandBy and CarPlay. Each widget can use its own lyric timing offset.
- **In-app lyrics**: Shows the current line and the next five lines, with playback, previous-track, and next-track controls.
- **Lyric timing adjustment**: Lyrics in the app and Live Activity can be shifted up to 10 seconds earlier or later in 0.5-second steps. The setting is saved.
- **Multiple lyric sources**: Queries LRCLIB, Kugou Music, and NetEase Cloud Music concurrently, then selects the first synchronized result in a fixed priority order. Plain, non-scrolling lyrics are used only when no synchronized result is available.
- **Simplified-to-Traditional Chinese conversion**: On devices configured for Traditional Chinese, synchronized Simplified Chinese lyrics are converted automatically. Plain lyric fallbacks are not currently converted.

## Requirements

- iPhone running iOS 26 or later (Dynamic Island requires an iPhone 14 Pro or a later compatible model)
- Xcode 26 or later
- An Apple Music subscription, with playback through Apple's built-in Music app

The project targets both iPhone and iPad, but the interface and functionality have only been validated on iPhone. iPad is not an officially supported platform.

## Installation

1. Open `AppleMusicLyricsWidget.xcodeproj` in Xcode.
2. Select your Development Team for both the app and widget targets.
3. The default bundle ID is `com.yuchen.AppleMusicLyricsWidget`, and the App Group is `group.com.yuchen.AppleMusicLyricsWidget`. If your account cannot use them, update `project.yml` and `Shared/AppConstants.swift`, then run `xcodegen generate`.
4. Connect your iPhone, choose it as the run destination, and run the app.

### Free Personal Team

Provisioning profiles for a free account do not support App Groups. Clear the entitlements when building:

```sh
xcodebuild -project AppleMusicLyricsWidget.xcodeproj \
  -scheme AppleMusicLyricsWidget \
  -destination 'id=<your device UDID>' \
  -derivedDataPath /tmp/AppleMusicLyricsWidget-DerivedData \
  DEVELOPMENT_TEAM=<your Team ID> CODE_SIGN_ENTITLEMENTS= \
  -allowProvisioningUpdates build
```

Without an App Group, the widget reads the current track and fetches lyrics independently. Keep DerivedData outside iCloud-synced folders to avoid code-signing failures.

### Changing project settings

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen). After adding files or changing `project.yml`, run `xcodegen generate` to regenerate the project.

## Usage

1. Open the app and allow Apple Music access.
2. Play a song in the Music app.
3. Return to the app and tap **Start** to create the Live Activity.
4. Follow the in-app prompt and change the app's Location permission to **Always** in Settings. See the next section for the reason.
5. To use a widget, add **Synced Lyrics** to the Home Screen or Lock Screen. Long-press the widget and choose **Edit Widget** to adjust its lyric timing.

### Troubleshooting

- If tapping **Start** does not create a Live Activity, make sure Live Activities are enabled for this app in the Settings app.
- If the Live Activity starts but stops updating after switching apps or locking the screen, make sure Location access is set to **Always**, then reopen the app.

## How background updates work

iOS does not allow an app to create a Live Activity while it is in the background. It also rejects Live Activity updates from an app that is only playing background media; the update call does not report an error, but the displayed content does not change. While a Live Activity is active, this app uses two mechanisms to keep updates running:

- **Silent audio playback** keeps the app executing in the background. The audio session mixes with other audio and does not interrupt Apple Music.
- **Lowest-accuracy background location updates** prevent the process from being classified as only playing background media. Location values are never read, stored, or uploaded.

Location updates start only when permission is set to **Always**. With **While Using the App** permission, iOS displays a location indicator in the Dynamic Island that covers the lyrics, so the app does not start location updates in that state and the Live Activity updates only while the app is in the foreground.

To reduce power use, the app sleeps until the next lyric line while in the background, checking at most every 2 seconds during playback and every 3 seconds while paused.

This approach is intended for personal use and is unlikely to pass App Store review. The standard solution uses ActivityKit push notifications, which require a paid developer account and a push server.

## Known limitations

- Lyric changes are best effort and may not align perfectly with the vocals. Use the timing adjustment to compensate.
- Unofficial providers such as Kugou and NetEase use approximate title, artist, and duration matching. Songs with the same title, covers, live recordings, or tracks of similar length may occasionally receive lyrics for the wrong version.
- When no lyrics are found, the app does not keep querying the same track. It searches again after the track changes or the app restarts. Network failures, rate limits, and server errors retry automatically after 30 seconds.
- Widget refresh timing is controlled by WidgetKit. If the app is fully terminated and the track changes, the widget may not update until the system next runs it.
- A Live Activity can remain active for up to 8 hours. After it ends, reopen the app to start another one.
- Reinstalling the app removes any active Live Activity.
- Synchronized Simplified Chinese lyrics are converted automatically and may occasionally contain conversion errors. Plain lyric fallbacks are not converted and do not filter credit lines such as lyricist or composer entries.

## Lyric sources and notices

| Source | Description |
|---|---|
| [LRCLIB](https://lrclib.net) | Public API with strong coverage for Western, Japanese, and Korean music |
| Kugou Music | Unofficial endpoint with strong Chinese-language coverage |
| NetEase Cloud Music | Unofficial endpoint covering Chinese, Japanese, Korean, and Western music |
| [lyrics.ovh](https://lyrics.ovh) | Plain lyrics only; final fallback |

LRCLIB, Kugou, and NetEase are queried concurrently, but synchronized lyrics are selected in the fixed priority order **LRCLIB → Kugou → NetEase**. If none provides synchronized lyrics, the app first uses any available plain lyrics from those results, then falls back to lyrics.ovh.

### Privacy and network access

When searching for lyrics, the app sends the current track title and artist to LRCLIB, Kugou, and NetEase. LRCLIB also receives the album and track duration, while Kugou also receives the track duration. If those sources do not provide usable plain lyrics, the app sends the artist and title to lyrics.ovh. These services are independent and subject to their own privacy policies and terms. The app does not send Apple Music account information or location coordinates to lyric services.

Apple Music lyrics are not available through a public API. Kugou and NetEase endpoints are unofficial and may stop working if their services change. Lyrics remain the property of their respective rights holders. This project is intended for personal learning and use; verify each service's terms and the applicable lyric licenses before redistribution or commercial use.

This project is not affiliated with Apple, LRCLIB, Kugou, or NetEase.

## License

The project's code and documentation are available under the [MIT License](LICENSE). The MIT License does not cover third-party lyrics, Apple's names or trademarks, or the services and data provided by LRCLIB, Kugou, NetEase, or lyrics.ovh; those remain subject to their respective rights holders and terms.

## Project structure

- `App/`: Main app, MusicKit playback monitoring, Live Activity management, and background execution
- `Shared/`: Data models, LRC parsing, lyric providers, colors, and state shared by the app and widgets
- `Widget/`: Widget and Live Activity interfaces
- `project.yml`: XcodeGen project definition
