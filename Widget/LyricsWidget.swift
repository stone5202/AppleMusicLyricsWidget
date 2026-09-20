import SwiftUI
import WidgetKit
@preconcurrency import MusicKit

struct LyricsTimelineEntry: TimelineEntry {
    let date: Date
    let state: SharedLyricsState

    var window: LyricsWindow { state.window(at: date) }
}

struct LyricsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricsTimelineEntry {
        LyricsTimelineEntry(
            date: .now,
            state: SharedLyricsState(
                track: TrackSnapshot(entryID: "demo", title: "七里香", artist: "周杰倫", album: "七里香", duration: 299),
                lines: [
                    LyricLine(time: 0, text: "雨下整夜"),
                    LyricLine(time: 4, text: "我的愛溢出就像雨水"),
                    LyricLine(time: 9, text: "窗台蝴蝶")
                ],
                plainLines: nil,
                referenceDate: .now,
                referencePlaybackTime: 0,
                isPlaying: true,
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LyricsTimelineEntry) -> Void) {
        Task {
            let state = await Self.loadState()
            completion(LyricsTimelineEntry(date: .now, state: state))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LyricsTimelineEntry>) -> Void) {
        Task {
            let state = await Self.loadState()
            let now = Date()
            var entries: [LyricsTimelineEntry] = [LyricsTimelineEntry(date: now, state: state)]

            if state.isPlaying, !state.lines.isEmpty {
                let currentTime = state.playbackTime(at: now)
                let future = state.lines
                    .filter { $0.time > currentTime + 0.05 }
                    .prefix(200)

                for line in future {
                    let date = now.addingTimeInterval(line.time - currentTime)
                    entries.append(LyricsTimelineEntry(date: date, state: state))
                }
            }

            let reload = max(now.addingTimeInterval(300), (entries.last?.date ?? now).addingTimeInterval(30))
            completion(Timeline(entries: entries, policy: .after(reload)))
        }
    }

    @MainActor
    private static func loadState() async -> SharedLyricsState {
        let shared = await SharedStateStore.shared.load()
        if shared.track != nil { return shared }

        let player = SystemMusicPlayer.shared
        guard let entry = player.queue.currentEntry else { return .empty }
        let snapshot = makeSnapshot(entry: entry, player: player)
        let result = try? await LRCLibLyricsProvider().lyrics(for: snapshot)
        guard player.queue.currentEntry?.id == entry.id else { return .empty }

        return SharedLyricsState(
            track: snapshot,
            lines: result?.syncedLines ?? [],
            plainLines: result?.plainLines,
            referenceDate: .now,
            referencePlaybackTime: max(0, player.playbackTime),
            isPlaying: player.state.playbackStatus == .playing,
            updatedAt: .now
        )
    }

    @MainActor
    private static func makeSnapshot(entry: MusicPlayer.Queue.Entry, player: SystemMusicPlayer) -> TrackSnapshot {
        var title = entry.title
        var artist = entry.subtitle ?? ""
        var album = ""
        var duration = max(player.playbackTime + 1, 1)

        if let item = entry.item {
            switch item {
            case .song(let song):
                title = song.title
                artist = song.artistName
                album = song.albumTitle ?? ""
                duration = song.duration ?? duration
            case .musicVideo(let video):
                title = video.title
                artist = video.artistName
                album = video.albumTitle ?? ""
                duration = video.duration ?? duration
            @unknown default:
                break
            }
        }

        return TrackSnapshot(entryID: entry.id, title: title, artist: artist, album: album, duration: duration)
    }
}

struct LyricsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LyricsTimelineEntry

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                Text(entry.window.current)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    if let track = entry.state.track {
                        Text(track.title + (entry.state.plainLines?.isEmpty == false ? " · 未同步" : ""))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    ViewThatFits(in: .vertical) {
                        lyricRows(showNext: true, showNext2: true)
                        lyricRows(showNext: true, showNext2: false)
                        lyricRows(showNext: false, showNext2: false)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func lyricRows(showNext: Bool, showNext2: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.window.current)
                .font(.headline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if showNext, let next = entry.window.next {
                Text(next)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.44))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showNext2, let next2 = entry.window.next2 {
                Text(next2)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.22))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LyricsWidget: Widget {
    let kind = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricsTimelineProvider()) { entry in
            LyricsWidgetView(entry: entry)
        }
        .configurationDisplayName("同步歌詞")
        .description("顯示目前 Apple Music 歌詞與接下來兩行。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
