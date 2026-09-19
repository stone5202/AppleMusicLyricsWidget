# AppleMusicLyricsWidget

Apple Music companion app focused on a glanceable synchronized-lyrics widget for iPhone, StandBy and CarPlay (iOS 26+).

## Features

- Reads the current Apple Music track using `SystemMusicPlayer` / MusicKit.
- Requests MusicKit authorization.
- Fetches synchronized LRC lyrics from LRCLIB (replaceable through `LyricsProvider`).
- Displays the current lyric at full opacity plus the next two lines at progressively lower opacity.
- Shares state between the app and Widget extension through an App Group.
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

## Lyrics source

This starter uses LRCLIB's public API and sends the required client identification header. Review LRCLIB terms and the music/lyrics licensing requirements applicable to your distribution before shipping commercially.

## Repository structure

- `App/` app, MusicKit monitor and LRCLIB provider
- `Shared/` models, LRC parser and App Group state store
- `Widget/` WidgetKit timeline provider and UI
- `project.yml` XcodeGen project definition

## Live Activity

The app also includes an ActivityKit Live Activity with Lock Screen, Dynamic Island, and CarPlay presentation. Start/end it from the app. Its content updates when the app receives execution time and the current lyric window changes.
