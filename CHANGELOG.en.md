# Changelog

[繁體中文](CHANGELOG.md) · [**English**](CHANGELOG.en.md)

## 1.0.0 — 2026-10-04

### Added

- Live Activity lyrics continue updating line by line after the app enters the background, including when the track changes.
- Added Kugou Music and NetEase Cloud Music as lyric sources. They are queried concurrently with LRCLIB, with synchronized lyrics preferred.
- Automatically converts synchronized Simplified Chinese lyrics to Traditional Chinese when the device language is Traditional Chinese.
- Filters common credit lines such as lyricist and composer entries from the beginning of synchronized lyric files.
- Added an app icon.
- Live Activities now show one additional lyric line, for a total of three.

### Changed

- Redesigned the app with a dark gradient, card-based layout, and centered lyrics.
- Updated widgets with gradient backgrounds and centered lyrics.
- Centered Live Activity lyrics. In the expanded Dynamic Island, the track title and artist now appear together above the lyrics so they are not clipped by the rounded corner.
- Track changes now update the existing Live Activity instead of ending it and creating a new one.
- In the background, the app now sleeps until the next lyric line to reduce power use.

### Notes

- Background updates require setting the app's Location permission to **Always**. See **How background updates work** in the README.

## 0.5.0 — 2026-09-20

- Each widget can use its own earlier or later lyric timing offset, defaulting to 1 second early.
- Added a refresh button to widgets.
- Added plain lyrics from lyrics.ovh as a fallback when LRCLIB has no result.

## 0.4.0 — 2026-09-20

- Added lyric timing adjustment of up to 10 seconds earlier or later for the app and Live Activity.
- Widget lyrics wrap according to the available size and show the next two lines when space allows.
- Start and End controls now show the current Live Activity state, and reopening the app reconnects to an existing Live Activity.

## 0.3.0 — 2026-09-20

- Without an App Group, the widget can read the current track and fetch lyrics independently, allowing widgets to work with a free Personal Team.

## 0.2.0 — 2026-09-20

- Added an Xcode project so the app can be built and installed directly from Xcode.
- The app now shows the current lyric line and the next five lines.
- Plain lyrics are displayed when synchronized lyrics are unavailable.

## 0.1.0 — 2026-09-20

- Initial release: reads the currently playing Apple Music track through MusicKit and retrieves synchronized lyrics from LRCLIB.
- Added small and medium Home Screen widgets and the rectangular Lock Screen widget.
- Added Dynamic Island and Lock Screen Live Activities.
