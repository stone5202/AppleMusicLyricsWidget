import ActivityKit
import SwiftUI
import WidgetKit

struct LyricsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricsActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    Text(context.state.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Text(context.state.current)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                if let next = context.state.next {
                    Text(next)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.42))
                        .lineLimit(1)
                }
                if let next2 = context.state.next2 {
                    Text(next2)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.22))
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "music.note")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.artist)
                        .font(.caption2)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.current)
                            .font(.headline)
                            .lineLimit(1)
                        if let next = context.state.next {
                            Text(next)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "music.note")
            } compactTrailing: {
                Text(context.state.current)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            } minimal: {
                Image(systemName: "music.note")
            }
        }
    }
}
