import Foundation

protocol LyricsProvider: Sendable {
    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult
}

struct LyricsResult: Sendable {
    let syncedLines: [LyricLine]
    let plainLines: [String]
}

struct FallbackLyricsProvider: LyricsProvider {
    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        do {
            return try await LRCLibLyricsProvider().lyrics(for: track)
        } catch {
            let primaryError = error
            do {
                return try await LyricsOvhLyricsProvider().lyrics(for: track)
            } catch {
                throw primaryError
            }
        }
    }
}

struct LyricsOvhLyricsProvider: LyricsProvider {
    private struct Response: Decodable {
        let lyrics: String
    }

    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        guard !track.artist.isEmpty, !track.title.isEmpty,
              let base = URL(string: "https://api.lyrics.ovh/v1") else {
            throw LyricsProviderError.invalidURL
        }
        let url = base.appendingPathComponent(track.artist).appendingPathComponent(track.title)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LyricsProviderError.notFound }
        guard (200..<300).contains(http.statusCode) else {
            throw http.statusCode == 404 ? LyricsProviderError.notFound : LyricsProviderError.http(http.statusCode)
        }
        let lyrics = try JSONDecoder().decode(Response.self, from: data).lyrics
        let lines = lyrics.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw LyricsProviderError.notFound }
        return LyricsResult(syncedLines: [], plainLines: lines)
    }
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
        case .noSyncedLyrics: "找到歌曲，但沒有可用的歌詞"
        case .http(let code): "歌詞服務回傳 HTTP \(code)"
        }
    }
}

struct LRCLibLyricsProvider: LyricsProvider {
    struct Response: Decodable {
        let trackName: String?
        let artistName: String?
        let duration: TimeInterval?
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist),
            .init(name: "album_name", value: track.album),
            .init(name: "duration", value: String(Int(track.duration.rounded())))
        ]
        guard let url = components?.url else { throw LyricsProviderError.invalidURL }

        let (data, http) = try await fetch(url)
        var fallbackPlainLines: [String] = []
        if (200..<300).contains(http.statusCode) {
            let payload = try JSONDecoder().decode(Response.self, from: data)
            if let synced = payload.syncedLyrics {
                let lines = LRCParser.parse(synced)
                if !lines.isEmpty { return LyricsResult(syncedLines: lines, plainLines: []) }
            }
            fallbackPlainLines = parsePlain(payload.plainLyrics)
        } else if http.statusCode != 404,
                  http.statusCode != 429,
                  !(500..<600).contains(http.statusCode) {
            throw LyricsProviderError.http(http.statusCode)
        }

        do {
            return try await searchLyrics(for: track)
        } catch {
            if !fallbackPlainLines.isEmpty {
                return LyricsResult(syncedLines: [], plainLines: fallbackPlainLines)
            }
            throw error
        }
    }

    private func searchLyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist)
        ]
        guard let url = components?.url else { throw LyricsProviderError.invalidURL }

        let (data, http) = try await fetch(url)
        guard (200..<300).contains(http.statusCode) else { throw LyricsProviderError.http(http.statusCode) }
        let results = try JSONDecoder().decode([Response].self, from: data)
        let title = normalized(track.title)
        let artist = normalized(track.artist)
        let matches = results.filter { result in
            guard let resultTitle = result.trackName,
                  let resultArtist = result.artistName,
                  normalized(resultTitle) == title,
                  normalized(resultArtist) == artist else { return false }
            guard track.duration >= 30, let duration = result.duration else { return true }
            return abs(duration - track.duration) <= 15
        }
        guard !matches.isEmpty else { throw LyricsProviderError.notFound }

        let ranked = matches.sorted {
            abs(($0.duration ?? track.duration) - track.duration)
                < abs(($1.duration ?? track.duration) - track.duration)
        }
        for result in ranked {
            guard let synced = result.syncedLyrics else { continue }
            let lines = LRCParser.parse(synced)
            if !lines.isEmpty { return LyricsResult(syncedLines: lines, plainLines: []) }
        }
        for result in ranked {
            let lines = parsePlain(result.plainLyrics)
            if !lines.isEmpty { return LyricsResult(syncedLines: [], plainLines: lines) }
        }
        throw LyricsProviderError.noSyncedLyrics
    }

    private func parsePlain(_ text: String?) -> [String] {
        guard let text else { return [] }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func fetch(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("AppleMusicLyricsWidget/0.1 (https://github.com/stone5202/AppleMusicLyricsWidget)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LyricsProviderError.notFound }
        return (data, http)
    }
}
