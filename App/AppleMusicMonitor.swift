import Foundation
import MusicKit
import Observation
import WidgetKit

@MainActor
@Observable
final class AppleMusicMonitor {
    private let player = SystemMusicPlayer.shared
    private let lyricsProvider: any LyricsProvider
    private var monitorTask: Task<Void, Never>?
    private var lastEntryID: String?

    var authorizationStatus = MusicAuthorization.currentStatus
    var track: TrackSnapshot?
    var lyrics: [LyricLine] = []
    var playbackTime: TimeInterval = 0
    var isPlaying = false
    var errorMessage: String?
    var currentWindow = LyricsWindow(current: "開啟 Apple Music 播放歌曲", next: nil, next2: nil)

    init(lyricsProvider: any LyricsProvider = LRCLibLyricsProvider()) {
        self.lyricsProvider = lyricsProvider
    }

    deinit { monitorTask?.cancel() }

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
            track = nil
            lyrics = []
            currentWindow = LyricsWindow(current: "Apple Music 尚未播放", next: nil, next2: nil)
            await persist()
            return
        }

        let snapshot = makeSnapshot(entry: entry)
        if entry.id != lastEntryID {
            lastEntryID = entry.id
            track = snapshot
            lyrics = []
            errorMessage = nil
            do {
                lyrics = try await lyricsProvider.lyrics(for: snapshot)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            track = snapshot
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

    private func makeState() -> SharedLyricsState {
        SharedLyricsState(
            track: track,
            lines: lyrics,
            referenceDate: .now,
            referencePlaybackTime: playbackTime,
            isPlaying: isPlaying,
            updatedAt: .now
        )
    }

    private func persist(_ state: SharedLyricsState? = nil) async {
        let snapshot = state ?? makeState()
        try? await SharedStateStore.shared.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
    }
}
