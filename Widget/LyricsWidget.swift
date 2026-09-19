import SwiftUI
import WidgetKit

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
                referenceDate: .now,
                referencePlaybackTime: 0,
                isPlaying: true,
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LyricsTimelineEntry) -> Void) {
        Task {
            let state = await SharedStateStore.shared.load()
            completion(LyricsTimelineEntry(date: .now, state: state))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LyricsTimelineEntry>) -> Void) {
        Task {
            let state = await SharedStateStore.shared.load()
            let now = Date()
            var entries: [LyricsTimelineEntry] = [LyricsTimelineEntry(date: now, state: state)]

            if state.isPlaying, !state.lines.isEmpty {
                let currentTime = state.playbackTime(at: now)
                let future = state.lines
                    .filter { $0.time > currentTime + 0.05 }
                    .prefix(80)

                for line in future {
                    let date = now.addingTimeInterval(line.time - currentTime)
                    entries.append(LyricsTimelineEntry(date: date, state: state))
                }
            }

            let reload = entries.last?.date.addingTimeInterval(30) ?? now.addingTimeInterval(60)
            completion(Timeline(entries: entries, policy: .after(reload)))
        }
    }
}

struct LyricsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LyricsTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let track = entry.state.track {
                Text(track.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(entry.window.current)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if let next = entry.window.next {
                Text(next)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if let next2 = entry.window.next2 {
                Text(next2)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
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
