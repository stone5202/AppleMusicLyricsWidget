import Foundation
@preconcurrency import MusicKit
import Observation
import WidgetKit

@MainActor
@Observable
final class AppleMusicMonitor {
    private static let lyricOffsetKey = "lyrics.timing.offset.v1"
    private let player = SystemMusicPlayer.shared
    private let lyricsProvider: any LyricsProvider
    private var monitorTask: Task<Void, Never>?
    private var lastEntryID: String?
    private var lastPersistedState: SharedLyricsState?
    private var nextLyricsRetryAt = Date.distantPast

    var authorizationStatus = MusicAuthorization.currentStatus
    var track: TrackSnapshot?
    var lyrics: [LyricLine] = []
    var plainLyrics: [String] = []
    var playbackTime: TimeInterval = 0
    var lyricOffset: TimeInterval = UserDefaults.standard.double(forKey: lyricOffsetKey)
    var isPlaying = false
    var errorMessage: String?
    var currentWindow = LyricsWindow(current: "開啟 Apple Music 播放歌曲", next: nil, next2: nil)

    init(lyricsProvider: any LyricsProvider = LRCLibLyricsProvider()) {
        self.lyricsProvider = lyricsProvider
    }

    isolated deinit { monitorTask?.cancel() }

    func start() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            guard let self else { return }
            authorizationStatus = await MusicAuthorization.request()
            guard authorizationStatus == .authorized else {
                errorMessage = "需要允許 Apple Music 存取權限。"
                return
            }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func refresh() async {
        let entry = player.queue.currentEntry
        let time = player.playbackTime
        let playing = player.state.playbackStatus == .playing

        playbackTime = time.isFinite ? max(0, time) : 0
        isPlaying = playing

        guard let entry else {
            lastEntryID = nil
            nextLyricsRetryAt = .distantPast
            track = nil
            lyrics = []
            plainLyrics = []
            currentWindow = LyricsWindow(current: "Apple Music 尚未播放", next: nil, next2: nil)
            await persist()
            return
        }

        let snapshot = makeSnapshot(entry: entry)
        if entry.id != lastEntryID {
            lastEntryID = entry.id
            lyrics = []
            plainLyrics = []
            errorMessage = nil
            nextLyricsRetryAt = .distantPast
        }
        track = snapshot

        if lyrics.isEmpty, plainLyrics.isEmpty, Date.now >= nextLyricsRetryAt {
            nextLyricsRetryAt = .distantFuture
            do {
                let result = try await lyricsProvider.lyrics(for: snapshot)
                lyrics = result.syncedLines
                plainLyrics = result.plainLines
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                if shouldRetryLyrics(after: error) {
                    nextLyricsRetryAt = .now.addingTimeInterval(30)
                }
            }
        }

        let state = makeState()
        currentWindow = state.window(at: .now)
        await LiveActivityManager.shared.update(track: track, window: currentWindow, isPlaying: isPlaying)
        await persist(state)
    }

    func playPause() async {
        do {
            if player.state.playbackStatus == .playing {
                player.pause()
            } else {
                try await player.play()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func next() async {
        do { try await player.skipToNextEntry() }
        catch { errorMessage = error.localizedDescription }
    }

    func previous() async {
        do { try await player.skipToPreviousEntry() }
        catch { errorMessage = error.localizedDescription }
    }

    func setLyricOffset(_ offset: TimeInterval) async {
        let adjusted = min(10, max(-10, (offset * 2).rounded() / 2))
        guard adjusted != lyricOffset else { return }
        lyricOffset = adjusted
        UserDefaults.standard.set(adjusted, forKey: Self.lyricOffsetKey)
        let state = makeState()
        currentWindow = state.window(at: .now)
        await LiveActivityManager.shared.update(track: track, window: currentWindow, isPlaying: isPlaying)
        await persist(state, force: true)
    }

    private func makeSnapshot(entry: MusicPlayer.Queue.Entry) -> TrackSnapshot {
        var title = entry.title
        var artist = entry.subtitle ?? ""
        var album = ""
        var duration: TimeInterval = max(player.playbackTime + 1, 1)

        if let item = entry.item {
            switch item {
            case .song(let song):
                title = song.title
                artist = song.artistName
                album = song.albumTitle ?? ""
                duration = song.duration ?? duration
            case .musicVideo(let video):
                title = video.title
                artist = video.artistName
                album = video.albumTitle ?? ""
                duration = video.duration ?? duration
            @unknown default:
                break
            }
        }

        return TrackSnapshot(entryID: entry.id, title: title, artist: artist, album: album, duration: duration)
    }

    private func shouldRetryLyrics(after error: Error) -> Bool {
        if let providerError = error as? LyricsProviderError {
            if case .http(let code) = providerError {
                return code == 429 || (500..<600).contains(code)
            }
            return false
        }
        return error is URLError
    }

    private func makeState() -> SharedLyricsState {
        SharedLyricsState(
            track: track,
            lines: lyrics,
            plainLines: plainLyrics.isEmpty ? nil : plainLyrics,
            referenceDate: .now,
            referencePlaybackTime: max(0, playbackTime + lyricOffset),
            isPlaying: isPlaying,
            updatedAt: .now
        )
    }

    private func persist(_ state: SharedLyricsState? = nil, force: Bool = false) async {
        let snapshot = state ?? makeState()
        let previous = lastPersistedState
        let changed = previous?.track != snapshot.track
            || previous?.lines != snapshot.lines
            || previous?.plainLines != snapshot.plainLines
            || previous?.isPlaying != snapshot.isPlaying
        let needsCorrection = previous.map { snapshot.updatedAt.timeIntervalSince($0.updatedAt) >= 60 } ?? true
        guard force || changed || needsCorrection else { return }

        do {
            try await SharedStateStore.shared.save(snapshot)
            lastPersistedState = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
