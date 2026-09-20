# AppleMusicLyricsWidget

Apple Music companion app focused on a glanceable synchronized-lyrics widget for iPhone, StandBy and CarPlay (iOS 26+).

## Features

- Reads the current Apple Music track using `SystemMusicPlayer` / MusicKit.
- Requests MusicKit authorization.
- Fetches synchronized LRC lyrics from LRCLIB (replaceable through `LyricsProvider`). If LRCLIB cannot find lyrics, it tries lyrics.ovh for plain text.
- Shows plain lyrics without timed highlighting when no synchronized version is available.
- Displays the current lyric plus five upcoming lines in the app. The widget wraps lyrics to fit its size and shows up to two upcoming lines when space allows.
- Lets you advance or delay app and Live Activity lyrics by up to 10 seconds in half-second steps; the setting is saved.
- Gives each widget its own lyric timing setting, defaulting to 1 second early, and a refresh button.
- Shares state through an App Group when available. Without one, the widget reads the current song and fetches lyrics itself.
- Builds future WidgetKit timeline entries from the track's lyric timestamps.
- `systemSmall` support for StandBy and CarPlay; `systemMedium` and Lock Screen rectangular widget included.

## Important platform behavior

CarPlay uses the small system widget. WidgetKit controls refresh scheduling, so lyric transitions are best-effort rather than frame-accurate. The app precomputes future timeline entries while a track is known. A track change that occurs while the app is fully suspended may not be visible until iOS gives the app/widget another execution opportunity.

## Setup

1. Install Xcode 26+ and open `AppleMusicLyricsWidget.xcodeproj`. The project is already generated; XcodeGen is needed only after editing `project.yml` (`xcodegen generate`).
2. The project currently uses `com.yuchen.AppleMusicLyricsWidget` and `group.com.yuchen.AppleMusicLyricsWidget`. If these identifiers are not available to your Apple Developer team, change them in `project.yml` and the App Group string in `Shared/AppConstants.swift`, then regenerate the project.
3. In Xcode, select your Development Team for both the app and widget targets. Connect an iPhone running iOS 26+ and select it as the run destination.
4. In Apple Developer Certificates, Identifiers & Profiles:
   - Enable MusicKit for the app identifier.
   - Enable App Groups for both app and widget identifiers.
   - Register the same App Group used by both targets.
5. Run the app on the iPhone and allow Apple Music access when prompted. Play a song in Apple Music.
6. Add the `同步歌詞` small widget. On iOS 26 CarPlay, configure it in the CarPlay Widgets screen.
7. To adjust widget timing independently, long-press the widget and choose Edit Widget. Positive seconds show lyrics earlier; negative seconds show them later.

### Personal Team testing

The app and widget normally use an App Group to share lyric state. A Personal Team provisioning profile may reject this entitlement. To test on your own iPhone, build with `CODE_SIGN_ENTITLEMENTS=` and your Personal Team selected. The widget then fetches lyrics independently when it cannot read shared state. Keep DerivedData outside an iCloud-synced Documents folder when code signing.

## Lyrics source

This starter uses LRCLIB's public API and sends the required client identification header. It also tries lyrics.ovh for plain lyrics when LRCLIB has none. Review both services' terms and the music/lyrics licensing requirements applicable to your distribution before shipping commercially.

## Repository structure

- `App/` app and MusicKit monitor
- `Shared/` models, LRC parser, LRCLIB provider and App Group state store
- `Widget/` WidgetKit timeline provider and UI
- `project.yml` XcodeGen project definition

## Live Activity

The app also includes an ActivityKit Live Activity with Lock Screen and Dynamic Island presentation. Start/end it from the app; the controls show whether it is active. It follows the app's lyric timing adjustment and reconnects to an existing activity when the app reopens. When Apple Music also uses the Dynamic Island, iOS may display the Live Activity in its minimal presentation, which shows only the first few characters of the current lyric; long-press to expand it. iOS may suspend the app after locking, so lyric and track changes cannot be guaranteed in the background. The card marks its content stale after 45 seconds without an update.
