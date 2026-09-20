import AppIntents

struct RefreshLyricsIntent: AppIntent {
    static let title: LocalizedStringResource = "重新整理歌詞"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
