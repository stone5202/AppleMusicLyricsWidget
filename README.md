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

1. Install Xcode 26+ and XcodeGen (`brew install xcodegen`).
2. Replace `com.example` in `project.yml` with your bundle ID prefix.
3. Replace `group.com.example.AppleMusicLyricsWidget` in both entitlement files and `Shared/AppConstants.swift` with an App Group you own.
4. In Apple Developer Certificates, Identifiers & Profiles:
   - Enable MusicKit for the app identifier.
   - Enable App Groups for both app and widget identifiers.
   - Register the same App Group used above.
5. Run `xcodegen generate`.
6. Open `AppleMusicLyricsWidget.xcodeproj` and select your Development Team.
7. Run on a physical iPhone with Apple Music access.
8. Add the `同步歌詞` small widget. On iOS 26 CarPlay, configure it in the CarPlay Widgets screen.

## Lyrics source

This starter uses LRCLIB's public API and sends the required client identification header. Review LRCLIB terms and the music/lyrics licensing requirements applicable to your distribution before shipping commercially.

## Repository structure

- `App/` app, MusicKit monitor and LRCLIB provider
- `Shared/` models, LRC parser and App Group state store
- `Widget/` WidgetKit timeline provider and UI
- `project.yml` XcodeGen project definition

## Live Activity

The app also includes an ActivityKit Live Activity with Lock Screen, Dynamic Island, and CarPlay presentation. Start/end it from the app. Its content updates when the app receives execution time and the current lyric window changes.
