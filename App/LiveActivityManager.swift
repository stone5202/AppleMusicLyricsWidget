@preconcurrency import ActivityKit
import AVFoundation
import CoreLocation
import Foundation
import UIKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private let staleInterval: TimeInterval = 120
    private var activity: Activity<LyricsActivityAttributes>?
    private var lastState: LyricsActivityAttributes.ContentState?
    private var lastUpdateAt: Date?

    private init() {
        activity = Activity<LyricsActivityAttributes>.activities.first
        lastState = activity?.content.state
        if isActive { BackgroundKeepAlive.shared.start() }
    }

    var isActive: Bool {
        guard let activity else { return false }
        return activity.activityState == .active || activity.activityState == .stale
    }

    func start(track: TrackSnapshot, window: LyricsWindow, isPlaying: Bool) async throws {
        if activity != nil {
            if isActive {
                BackgroundKeepAlive.shared.start()
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
        BackgroundKeepAlive.shared.start()
    }

    // 換歌或暫無歌曲時只更新內容：背景中無法重新 request 即時動態，結束後就回不來。
    func update(track: TrackSnapshot?, window: LyricsWindow, isPlaying: Bool) async {
        guard let activity else { return }
        guard isActive else {
            self.activity = nil
            lastState = nil
            BackgroundKeepAlive.shared.stop()
            return
        }
        let state = makeState(track: track, window: window, isPlaying: isPlaying)
        let needsFreshness = Date.now.timeIntervalSince(lastUpdateAt ?? .distantPast) >= staleInterval - 15
        guard state != lastState || needsFreshness else { return }
        await activity.update(ActivityContent(state: state, staleDate: .now.addingTimeInterval(staleInterval), relevanceScore: 100))
        lastUpdateAt = .now
        lastState = state
    }

    func end() async {
        for activity in Activity<LyricsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        lastState = nil
        BackgroundKeepAlive.shared.stop()
    }

    private func makeState(track: TrackSnapshot?, window: LyricsWindow, isPlaying: Bool) -> LyricsActivityAttributes.ContentState {
        .init(
            title: track?.title ?? "Lyrics Widget",
            artist: track?.artist ?? "",
            current: window.current,
            next: window.next,
            next2: window.next2,
            isPlaying: isPlaying
        )
    }
}

/// 即時動態開啟期間讓 App 在背景持續執行並逐行更新歌詞。
/// 靜音音訊（mixWithOthers，不會中斷 Apple Music）負責保持執行；
/// 但 iOS 禁止「只播放背景媒體」的行程更新即時動態（liveactivitiesd 會默默丟棄 update），
/// 所以同時開啟最低精度的背景定位；UIKit background task 試過無效。
/// 定位只在「永遠」權限下啟用：「使用 App 期間」時系統的定位指示會佔用動態島蓋掉歌詞。
@MainActor
final class BackgroundKeepAlive: NSObject {
    static let shared = BackgroundKeepAlive()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let silence: AVAudioPCMBuffer?
    private var observers: [any NSObjectProtocol] = []
    private(set) var isRunning = false
    private let locationManager = CLLocationManager()

    /// 沒有「永遠」定位權限時，即時動態在背景不會更新。
    var needsAlwaysAuthorization: Bool {
        locationManager.authorizationStatus != .authorizedAlways
    }

    private override init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        let frames = AVAudioFrameCount(44_100)
        if let format, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) {
            buffer.frameLength = frames
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    channels[channel].update(repeating: 0, count: Int(frames))
                }
            }
            silence = buffer
        } else {
            silence = nil
        }
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = CLLocationDistanceMax
        locationManager.pausesLocationUpdatesAutomatically = false
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.ended.rawValue else { return }
                Task { @MainActor in self?.resume() }
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.resume() }
            },
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.resume() }
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.resume() }
            }
        ]
        resume()
        resumeLocation()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        locationManager.stopUpdatingLocation()
    }

    private func resumeLocation() {
        guard isRunning else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.showsBackgroundLocationIndicator = false
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    private func resume() {
        guard isRunning, let silence else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
            if !player.isPlaying {
                player.stop()
                player.scheduleBuffer(silence, at: nil, options: .loops)
                player.play()
            }
        } catch {
            // 中斷結束、音訊路徑變更或 App 回到前景時會再試一次。
        }
    }
}

extension BackgroundKeepAlive: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.resumeLocation() }
    }

    // 位置資料本身不使用也不儲存，只需要背景定位的執行資格。
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
