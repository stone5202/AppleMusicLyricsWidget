import ActivityKit
import SwiftUI
import WidgetKit

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            VStack(alignment: .center, spacing: 6) {
                HStack {
                    Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                        .foregroundStyle(Theme.accent)
                    Text(context.state.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Text(context.isStale ? "開啟 App 更新歌詞" : context.state.current)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !context.isStale, let next = context.state.next {
                    Text(next)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.42))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                if !context.isStale, let next2 = context.state.next2 {
                    Text(next2)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.26))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .center, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                                .foregroundStyle(Theme.accent)
                            Text(context.state.artist.isEmpty
                                 ? context.state.title
                                 : "\(context.state.title) · \(context.state.artist)")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 12)

                        Text(context.isStale ? "開啟 App 更新歌詞" : context.state.current)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if !context.isStale, let next = context.state.next {
                            Text(next)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        if !context.isStale, let next2 = context.state.next2 {
                            Text(next2)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .foregroundStyle(Theme.accent)
            } compactTrailing: {
                Text(context.isStale ? "需更新" : context.state.current)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            } minimal: {
                Text(context.isStale ? "…" : String(context.state.current.prefix(3)))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .keylineTint(Theme.accent)
        }
    }
}
