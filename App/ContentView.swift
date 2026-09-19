import SwiftUI

struct ContentView: View {
    @Bindable var monitor: AppleMusicMonitor

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(monitor.track?.title ?? "Apple Music Lyrics")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(monitor.track?.artist ?? "開始播放一首 Apple Music 歌曲")
                        .foregroundStyle(.secondary)
                }

                LyricsStackView(window: monitor.currentWindow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.thinMaterial, in: .rect(cornerRadius: 24))

                HStack(spacing: 34) {
                    Button { Task { await monitor.previous() } } label: {
                        Image(systemName: "backward.fill")
                    }
                    Button { Task { await monitor.playPause() } } label: {
                        Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    Button { Task { await monitor.next() } } label: {
                        Image(systemName: "forward.fill")
                    }
                }
                .buttonStyle(.plain)
                .font(.title3)

                if let track = monitor.track {
                    HStack {
                        Button("開始即時動態") {
                            Task {
                                try? await LiveActivityManager.shared.start(
                                    track: track,
                                    window: monitor.currentWindow,
                                    isPlaying: monitor.isPlaying
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("結束") {
                            Task { await LiveActivityManager.shared.end() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let error = monitor.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Lyrics Widget")
        }
    }
}

struct LyricsStackView: View {
    let window: LyricsWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(window.current)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if let next = window.next {
                Text(next)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.46))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let next2 = window.next2 {
                Text(next2)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.24))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}
