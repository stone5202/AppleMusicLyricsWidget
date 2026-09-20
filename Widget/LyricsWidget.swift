import SwiftUI
import WidgetKit
import AppIntents
@preconcurrency import MusicKit

struct LyricsWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "歌詞時間調整"
    static let description = IntentDescription("小工具可使用獨立的歌詞時間偏移。正數提早，負數延後。")

    @Parameter(title: "小工具提早秒數", default: 1.0)
    var advanceSeconds: Double
}

struct LyricsTimelineEntry: TimelineEntry {
    let date: Date
    let state: SharedLyricsState
    let advanceSeconds: TimeInterval

    var window: LyricsWindow { state.window(at: date, offset: advanceSeconds) }
}

struct LyricsTimelineProvider: AppIntentTimelineProvider {
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
            ),
            advanceSeconds: 1.0
        )
    }

    func snapshot(for configuration: LyricsWidgetConfiguration, in context: Context) async -> LyricsTimelineEntry {
        let state = await Self.loadState()
        return LyricsTimelineEntry(date: .now, state: state, advanceSeconds: Self.offset(for: configuration))
    }

    func timeline(for configuration: LyricsWidgetConfiguration, in context: Context) async -> Timeline<LyricsTimelineEntry> {
        let state = await Self.loadState()
        let now = Date()
        let offset = Self.offset(for: configuration)
        var entries: [LyricsTimelineEntry] = [LyricsTimelineEntry(date: now, state: state, advanceSeconds: offset)]

        if state.isPlaying, !state.lines.isEmpty {
            let currentTime = state.playbackTime(at: now) + offset
            let future = state.lines
                .filter { $0.time > currentTime + 0.05 }
                .prefix(200)

            for line in future {
                let date = now.addingTimeInterval(line.time - currentTime)
                entries.append(LyricsTimelineEntry(date: date, state: state, advanceSeconds: offset))
            }
        }

        let reload = max(now.addingTimeInterval(300), (entries.last?.date ?? now).addingTimeInterval(30))
        return Timeline(entries: entries, policy: .after(reload))
    }

    private static func offset(for configuration: LyricsWidgetConfiguration) -> TimeInterval {
        min(10, max(-10, configuration.advanceSeconds))
    }

    @MainActor
    private static func loadState() async -> SharedLyricsState {
        let shared = await SharedStateStore.shared.load()
        let player = SystemMusicPlayer.shared
        guard let entry = player.queue.currentEntry else { return shared }
        let snapshot = makeSnapshot(entry: entry, player: player)
        if shared.track?.entryID == entry.id,
           !shared.lines.isEmpty || shared.plainLines?.isEmpty == false {
            return SharedLyricsState(
                track: snapshot,
                lines: shared.lines,
                plainLines: shared.plainLines,
                referenceDate: .now,
                referencePlaybackTime: max(0, player.playbackTime),
                isPlaying: player.state.playbackStatus == .playing,
                updatedAt: .now
            )
        }
        let result = try? await FallbackLyricsProvider().lyrics(for: snapshot)
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
                HStack(spacing: 3) {
                    Text(entry.window.current)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    refreshButton
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) {
                        if let track = entry.state.track {
                            Text(track.title + (entry.state.plainLines?.isEmpty == false ? " · 未同步" : ""))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        refreshButton
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

    private var refreshButton: some View {
        Button(intent: RefreshLyricsIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("重新整理歌詞")
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
        AppIntentConfiguration(kind: kind, intent: LyricsWidgetConfiguration.self, provider: LyricsTimelineProvider()) { entry in
            LyricsWidgetView(entry: entry)
        }
        .configurationDisplayName("同步歌詞")
        .description("顯示目前 Apple Music 歌詞與接下來兩行；可單獨調整顯示時間。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
