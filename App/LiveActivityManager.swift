import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<LyricsActivityAttributes>?
    private var lastState: LyricsActivityAttributes.ContentState?

    var isActive: Bool { activity != nil }

    func start(track: TrackSnapshot, window: LyricsWindow, isPlaying: Bool) async throws {
        if activity != nil { return }
        let attributes = LyricsActivityAttributes(entryID: track.entryID)
        let state = makeState(track: track, window: window, isPlaying: isPlaying)
        activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
        lastState = state
    }

    func update(track: TrackSnapshot?, window: LyricsWindow, isPlaying: Bool) async {
        guard let activity, let track else { return }
        let state = makeState(track: track, window: window, isPlaying: isPlaying)
        guard state != lastState else { return }
        await activity.update(ActivityContent(state: state, staleDate: nil))
        lastState = state
    }

    func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
        lastState = nil
    }

    private func makeState(track: TrackSnapshot, window: LyricsWindow, isPlaying: Bool) -> LyricsActivityAttributes.ContentState {
        .init(
            title: track.title,
            artist: track.artist,
            current: window.current,
            next: window.next,
            next2: window.next2,
            isPlaying: isPlaying
        )
    }
}
