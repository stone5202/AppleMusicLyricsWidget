import ActivityKit
import Foundation

struct LyricsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let artist: String
        let current: String
        let next: String?
        let next2: String?
        let isPlaying: Bool
    }

    let entryID: String
}
