import SwiftUI

struct ContentView: View {
    @Bindable var monitor: AppleMusicMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text(monitor.track?.title ?? "Apple Music Lyrics")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(monitor.track?.artist ?? "開始播放一首 Apple Music 歌曲")
                            .foregroundStyle(.secondary)
                    }

                    LyricsStackView(
                        lines: monitor.lyrics,
                        plainLines: monitor.plainLyrics,
                        playbackTime: monitor.playbackTime,
                        fallback: monitor.currentWindow.current
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(.thinMaterial, in: .rect(cornerRadius: 24))

                    HStack(spacing: 34) {
                        Button {
                            Task { await monitor.previous() }
                        } label: {
                            Image(systemName: "backward.fill")
                        }
                        Button {
                            Task { await monitor.playPause() }
                        } label: {
                            Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        Button {
                            Task { await monitor.next() }
                        } label: {
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
                }
                .padding()
            }
            .navigationTitle("Lyrics Widget")
        }
    }
}

struct LyricsStackView: View {
    let lines: [LyricLine]
    let plainLines: [String]
    let playbackTime: TimeInterval
    let fallback: String

    private var currentIndex: Int {
        lines.lastIndex(where: { $0.time <= playbackTime }) ?? 0
    }

    private var visibleIndices: Range<Int> {
        currentIndex..<min(currentIndex + 6, lines.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !lines.isEmpty {
                ForEach(visibleIndices, id: \.self) { index in
                    Text(lines[index].text)
                        .font(
                            index == currentIndex
                                ? .title3.weight(.semibold) : .subheadline.weight(.medium)
                        )
                        .foregroundStyle(
                            .primary.opacity(
                                index == currentIndex
                                    ? 1 : max(0.35, 0.8 - Double(index - currentIndex) * 0.11))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if !plainLines.isEmpty {
                Text("一般歌詞 · 未同步")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(plainLines.indices, id: \.self) { index in
                            Text(plainLines[index])
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 340)
            } else {
                Text(fallback)
                    .font(.title3.weight(.semibold))
            }
        }
    }
}
