import Foundation

protocol LyricsProvider: Sendable {
    func lyrics(for track: TrackSnapshot) async throws -> [LyricLine]
}

enum LyricsProviderError: Error, LocalizedError {
    case invalidURL
    case notFound
    case noSyncedLyrics
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "歌詞查詢網址無效"
        case .notFound: "找不到這首歌的歌詞"
        case .noSyncedLyrics: "找到歌曲，但沒有同步時間軸歌詞"
        case .http(let code): "歌詞服務回傳 HTTP \(code)"
        }
    }
}

struct LRCLibLyricsProvider: LyricsProvider {
    struct Response: Decodable {
        let syncedLyrics: String?
    }

    func lyrics(for track: TrackSnapshot) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist),
            .init(name: "album_name", value: track.album),
            .init(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        guard let url = components?.url else { throw LyricsProviderError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("AppleMusicLyricsWidget/0.1 (https://github.com/stone5202/AppleMusicLyricsWidget)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LyricsProviderError.notFound }
        if http.statusCode == 404 { throw LyricsProviderError.notFound }
        guard (200..<300).contains(http.statusCode) else { throw LyricsProviderError.http(http.statusCode) }

        let payload = try JSONDecoder().decode(Response.self, from: data)
        guard let synced = payload.syncedLyrics, !synced.isEmpty else { throw LyricsProviderError.noSyncedLyrics }
        let lines = LRCParser.parse(synced)
        guard !lines.isEmpty else { throw LyricsProviderError.noSyncedLyrics }
        return lines
    }
}
