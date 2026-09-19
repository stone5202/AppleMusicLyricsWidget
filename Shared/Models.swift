import Foundation

struct LyricLine: Codable, Hashable, Identifiable, Sendable {
    var id: String { "\(time)-\(text)" }
    let time: TimeInterval
    let text: String
}

struct TrackSnapshot: Codable, Hashable, Sendable {
    let entryID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
}

struct SharedLyricsState: Codable, Hashable, Sendable {
    let track: TrackSnapshot?
    let lines: [LyricLine]
    let referenceDate: Date
    let referencePlaybackTime: TimeInterval
    let isPlaying: Bool
    let updatedAt: Date

    static let empty = SharedLyricsState(
        track: nil,
        lines: [],
        referenceDate: .now,
        referencePlaybackTime: 0,
        isPlaying: false,
        updatedAt: .now
    )

    func playbackTime(at date: Date) -> TimeInterval {
        guard isPlaying else { return referencePlaybackTime }
        return max(0, referencePlaybackTime + date.timeIntervalSince(referenceDate))
    }

    func currentIndex(at date: Date) -> Int? {
        let t = playbackTime(at: date)
        return lines.lastIndex(where: { $0.time <= t })
    }

    func window(at date: Date) -> LyricsWindow {
        guard let index = currentIndex(at: date), lines.indices.contains(index) else {
            return LyricsWindow(current: lines.first?.text ?? "等待同步歌詞…", next: lines.dropFirst().first?.text, next2: lines.dropFirst(2).first?.text)
        }
        return LyricsWindow(
            current: lines[index].text,
            next: lines.indices.contains(index + 1) ? lines[index + 1].text : nil,
            next2: lines.indices.contains(index + 2) ? lines[index + 2].text : nil
        )
    }
}

struct LyricsWindow: Codable, Hashable, Sendable {
    let current: String
    let next: String?
    let next2: String?
}
