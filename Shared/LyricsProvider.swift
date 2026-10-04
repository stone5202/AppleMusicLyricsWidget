import Foundation

protocol LyricsProvider: Sendable {
    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult
}

struct LyricsResult: Sendable {
    let syncedLines: [LyricLine]
    let plainLines: [String]
}

struct FallbackLyricsProvider: LyricsProvider {
    // 同時查詢所有來源，依序採用第一個有時間軸的結果；都沒有才退回不會動的一般歌詞。
    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        async let lrclib = attempt(LRCLibLyricsProvider(), track)
        async let kugou = attempt(KugouLyricsProvider(), track)
        async let netEase = attempt(NetEaseLyricsProvider(), track)
        let results = await [lrclib, kugou, netEase]
        let found = results.compactMap { try? $0.get() }

        for result in found {
            let lines = result.syncedLines.filter { !isCreditLine($0.text) }
            if !lines.isEmpty {
                return LyricsResult(syncedLines: ChineseScript.traditionalizedIfNeeded(lines), plainLines: [])
            }
        }
        if let plain = found.first(where: { !$0.plainLines.isEmpty }) { return plain }
        if let plain = try? await LyricsOvhLyricsProvider().lyrics(for: track) { return plain }
        if case .failure(let error) = results[0] { throw error }
        throw LyricsProviderError.notFound
    }

    private func attempt(_ provider: some LyricsProvider, _ track: TrackSnapshot) async -> Result<LyricsResult, any Error> {
        do { return .success(try await provider.lyrics(for: track)) }
        catch { return .failure(error) }
    }
}

/// 酷狗音樂：以「歌手 - 歌名」加長度搜尋，回傳 LRC 時間軸歌詞。非官方介面。
struct KugouLyricsProvider: LyricsProvider {
    private struct Search: Decodable {
        struct Candidate: Decodable {
            let id: String
            let accesskey: String
            let duration: Double?
        }
        let candidates: [Candidate]?
    }

    private struct Download: Decodable {
        let content: String?
    }

    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        // 搜尋結果無法驗證歌名，只能靠長度比對，長度未知時不採用。
        guard track.duration >= 30, !track.title.isEmpty else { throw LyricsProviderError.notFound }
        var components = URLComponents(string: "https://krcs.kugou.com/search")
        components?.queryItems = [
            .init(name: "ver", value: "1"),
            .init(name: "man", value: "yes"),
            .init(name: "client", value: "mobi"),
            .init(name: "keyword", value: track.artist.isEmpty ? track.title : "\(track.artist) - \(track.title)"),
            .init(name: "duration", value: String(Int(track.duration * 1000))),
            .init(name: "hash", value: "")
        ]
        guard let url = components?.url else { throw LyricsProviderError.invalidURL }
        let search = try JSONDecoder().decode(Search.self, from: try await fetchLyricsData(URLRequest(url: url)))
        let candidates = (search.candidates ?? []).filter {
            guard let duration = $0.duration else { return false }
            return abs(duration / 1000 - track.duration) <= 3
        }

        for candidate in candidates.prefix(3) {
            var download = URLComponents(string: "https://lyrics.kugou.com/download")
            download?.queryItems = [
                .init(name: "ver", value: "1"),
                .init(name: "client", value: "pc"),
                .init(name: "id", value: candidate.id),
                .init(name: "accesskey", value: candidate.accesskey),
                .init(name: "fmt", value: "lrc"),
                .init(name: "charset", value: "utf8")
            ]
            guard let url = download?.url,
                  let data = try? await fetchLyricsData(URLRequest(url: url)),
                  let content = try? JSONDecoder().decode(Download.self, from: data).content,
                  let decoded = Data(base64Encoded: content),
                  let lrc = String(data: decoded, encoding: .utf8) else { continue }
            let lines = LRCParser.parse(lrc)
            if !lines.isEmpty { return LyricsResult(syncedLines: lines, plainLines: []) }
        }
        throw LyricsProviderError.notFound
    }
}

/// 網易雲音樂：搜尋後以歌名與長度比對，回傳 LRC 時間軸歌詞。非官方介面。
struct NetEaseLyricsProvider: LyricsProvider {
    private struct Search: Decodable {
        struct Result: Decodable { let songs: [Song]? }
        struct Song: Decodable {
            let id: Int
            let name: String
            let artists: [Artist]?
            let duration: Double?
        }
        struct Artist: Decodable { let name: String }
        let result: Result?
    }

    private struct Lyric: Decodable {
        struct LRC: Decodable { let lyric: String? }
        let lrc: LRC?
    }

    func lyrics(for track: TrackSnapshot) async throws -> LyricsResult {
        guard track.duration >= 30, !track.title.isEmpty,
              let url = URL(string: "https://music.163.com/api/search/get") else { throw LyricsProviderError.notFound }
        var form = URLComponents()
        form.queryItems = [
            .init(name: "s", value: "\(track.title) \(track.artist)"),
            .init(name: "type", value: "1"),
            .init(name: "limit", value: "10"),
            .init(name: "offset", value: "0")
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let search = try JSONDecoder().decode(Search.self, from: try await fetchLyricsData(request))

        let title = matchKey(track.title)
        let artist = matchKey(track.artist)
        func artistMatches(_ song: Search.Song) -> Bool {
            (song.artists ?? []).contains {
                let name = matchKey($0.name)
                return !name.isEmpty && (name.contains(artist) || artist.contains(name))
            }
        }
        let matches = (search.result?.songs ?? [])
            .filter { song in
                guard let duration = song.duration, abs(duration / 1000 - track.duration) <= 3 else { return false }
                let name = matchKey(song.name)
                return !name.isEmpty && (name.contains(title) || title.contains(name))
            }
            .sorted { artistMatches($0) && !artistMatches($1) }

        for song in matches.prefix(3) {
            guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(song.id)&lv=1&kv=1&tv=-1"),
                  let data = try? await fetchLyricsData(URLRequest(url: url)),
                  let lrc = try? JSONDecoder().decode(Lyric.self, from: data).lrc?.lyric else { continue }
            let lines = LRCParser.parse(lrc)
            if !lines.isEmpty { return LyricsResult(syncedLines: lines, plainLines: []) }
        }
        throw LyricsProviderError.notFound
    }
}

private func fetchLyricsData(_ request: URLRequest) async throws -> Data {
    var request = request
    request.timeoutInterval = 8
    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
    if request.url?.host()?.hasSuffix("163.com") == true {
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw LyricsProviderError.notFound }
    guard (200..<300).contains(http.statusCode) else { throw LyricsProviderError.http(http.statusCode) }
    return data
}

private let creditLine = try! NSRegularExpression(
    pattern: #"^\s*(作[词詞曲]|[编編]曲|[制製]作人?|[监監][制製]|混音|[录錄]音|母[带帶]|和[声聲]|吉他|出品|[词詞]|曲|(composed|written|lyrics|produced|arranged|mixed|mastered) by|composer|lyricist|producer|arranger)\s*[:：]"#,
    options: .caseInsensitive
)

/// 歌詞檔開頭常見的「作詞：」「Composed by：」等製作名單，不是歌詞。
private func isCreditLine(_ text: String) -> Bool {
    creditLine.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
}

/// 比對用：忽略大小寫、全半形、簡繁與標點差異。
private func matchKey(_ value: String) -> String {
    let simplified = value.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? value
    return simplified
        .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .joined()
}

enum ChineseScript {
    /// 使用者偏好繁體中文時，把簡體歌詞轉成繁體；日文或本來就是繁體的歌詞不動。
    static func traditionalizedIfNeeded(_ lines: [LyricLine]) -> [LyricLine] {
        guard let language = Locale.preferredLanguages.first,
              language.hasPrefix("zh-Hant") || language.hasSuffix("-TW") || language.hasSuffix("-HK") else { return lines }
        let text = lines.map(\.text).joined(separator: "\n")
        let hasKana = text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
        guard !hasKana,
              text.applyingTransform(StringTransform("Hant-Hans"), reverse: false) == text,
              let converted = text.applyingTransform(StringTransform("Hans-Hant"), reverse: false),
              converted != text else { return lines }
        let convertedLines = converted.components(separatedBy: "\n")
        guard convertedLines.count == lines.count else { return lines }
        return zip(lines, convertedLines).map { LyricLine(time: $0.time, text: $1) }
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
        request.setValue("AppleMusicLyricsWidget/1.0 (https://github.com/stone5202/AppleMusicLyricsWidget)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LyricsProviderError.notFound }
        return (data, http)
    }
}
