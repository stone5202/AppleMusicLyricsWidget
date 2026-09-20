@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private let staleInterval: TimeInterval = 45
    private var activity: Activity<LyricsActivityAttributes>?
    private var lastState: LyricsActivityAttributes.ContentState?

    private init() {
        activity = Activity<LyricsActivityAttributes>.activities.first
        lastState = activity?.content.state
    }

    var isActive: Bool {
        guard let activity else { return false }
        return activity.activityState == .active || activity.activityState == .stale
    }

    func start(track: TrackSnapshot, window: LyricsWindow, isPlaying: Bool) async throws {
        if let activity {
            if isActive, activity.attributes.entryID == track.entryID {
                await update(track: track, window: window, isPlaying: isPlaying)
                return
            }
            await end()
        }
        let attributes = LyricsActivityAttributes(entryID: track.entryID)
        let state = makeState(track: track, window: window, isPlaying: isPlaying)
        activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: .now.addingTimeInterval(staleInterval), relevanceScore: 100),
            pushType: nil
        )
        lastState = state
    }

    func update(track: TrackSnapshot?, window: LyricsWindow, isPlaying: Bool) async {
        guard let activity else { return }
        guard isActive else {
            self.activity = nil
            lastState = nil
            return
        }
        guard let track else {
            await end()
            return
        }
        if activity.attributes.entryID != track.entryID {
            await end()
            try? await start(track: track, window: window, isPlaying: isPlaying)
            return
        }
        let state = makeState(track: track, window: window, isPlaying: isPlaying)
        let needsFreshness = (activity.content.staleDate ?? .distantPast) < .now.addingTimeInterval(15)
        guard state != lastState || needsFreshness else { return }
        await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(staleInterval), relevanceScore: 100))
        lastState = state
    }

    func end() async {
        for activity in Activity<LyricsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
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
