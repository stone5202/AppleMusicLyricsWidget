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
    let plainLines: [String]?
    let referenceDate: Date
    let referencePlaybackTime: TimeInterval
    let isPlaying: Bool
    let updatedAt: Date

    static let empty = SharedLyricsState(
        track: nil,
        lines: [],
        plainLines: nil,
        referenceDate: .now,
        referencePlaybackTime: 0,
        isPlaying: false,
        updatedAt: .now
    )

    func playbackTime(at date: Date) -> TimeInterval {
        guard isPlaying else { return referencePlaybackTime }
        return max(0, referencePlaybackTime + date.timeIntervalSince(referenceDate))
    }

    func currentIndex(at date: Date, offset: TimeInterval = 0) -> Int? {
        let t = max(0, playbackTime(at: date) + offset)
        return lines.lastIndex(where: { $0.time <= t })
    }

    func window(at date: Date, offset: TimeInterval = 0) -> LyricsWindow {
        if lines.isEmpty, let plainLines, !plainLines.isEmpty {
            return LyricsWindow(
                current: plainLines[0],
                next: plainLines.dropFirst().first,
                next2: plainLines.dropFirst(2).first
            )
        }
        guard let index = currentIndex(at: date, offset: offset), lines.indices.contains(index) else {
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
