import SwiftUI

struct ContentView: View {
    @Bindable var monitor: AppleMusicMonitor
    @State private var draftLyricOffset: Double = 0
    @State private var liveActivityActive = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header

                    LyricsStackView(
                        lines: monitor.lyrics,
                        plainLines: monitor.plainLyrics,
                        playbackTime: max(0, monitor.playbackTime + monitor.lyricOffset),
                        fallback: monitor.currentWindow.current
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .card(padding: 24)

                    controls
                        .padding(.vertical, 4)

                    timingCard

                    if let track = monitor.track {
                        liveActivityCard(track: track)
                    }

                    if let error = monitor.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onAppear {
            draftLyricOffset = monitor.lyricOffset
            liveActivityActive = LiveActivityManager.shared.isActive
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(monitor.track?.title ?? "Lyrics Widget")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(monitor.track?.artist ?? "開始播放一首 Apple Music 歌曲")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if monitor.track != nil {
                Text(lyricsStatus)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var lyricsStatus: String {
        if !monitor.lyrics.isEmpty { return "同步歌詞" }
        if !monitor.plainLyrics.isEmpty { return "一般歌詞 · 未同步" }
        return monitor.errorMessage == nil ? "尋找歌詞中…" : "沒有歌詞"
    }

    private var controls: some View {
        HStack(spacing: 30) {
            controlButton("backward.fill", label: "上一首") { await monitor.previous() }

            Button {
                Task { await monitor.playPause() }
            } label: {
                Image(systemName: monitor.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Theme.accentGradient, in: .circle)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(monitor.isPlaying ? "暫停" : "播放")

            controlButton("forward.fill", label: "下一首") { await monitor.next() }
        }
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.white.opacity(0.1), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var timingCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("歌詞時間調整", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(offsetDescription)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $draftLyricOffset,
                in: -10...10,
                step: 0.5,
                onEditingChanged: { isEditing in
                    if !isEditing { applyOffset(draftLyricOffset) }
                }
            )
            HStack {
                Button("延後 0.5 秒") { applyOffset(draftLyricOffset - 0.5) }
                Spacer()
                Button("重設") { applyOffset(0) }
                Spacer()
                Button("提早 0.5 秒") { applyOffset(draftLyricOffset + 0.5) }
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.75))
        }
        .card()
    }

    private func liveActivityCard(track: TrackSnapshot) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("即時動態", systemImage: "waveform")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(liveActivityActive ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 7, height: 7)
                    Text(liveActivityActive ? "已開啟" : "未開啟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        do {
                            try await LiveActivityManager.shared.start(
                                track: track,
                                window: monitor.currentWindow,
                                isPlaying: monitor.isPlaying
                            )
                            liveActivityActive = LiveActivityManager.shared.isActive
                        } catch {
                            monitor.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Text("開始").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(liveActivityActive || (monitor.lyrics.isEmpty && monitor.plainLyrics.isEmpty))

                Button {
                    Task {
                        await LiveActivityManager.shared.end()
                        liveActivityActive = false
                    }
                } label: {
                    Text("結束").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!liveActivityActive)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)

            Text(liveActivityActive
                 ? "已顯示於鎖定畫面與動態島。若歌詞停止更新，重新開啟 App 即可恢復。"
                 : "開啟後會顯示於鎖定畫面與動態島。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if BackgroundKeepAlive.shared.needsAlwaysAuthorization {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("要在背景更新歌詞，請到設定把「位置」改為「永遠」")
                        .font(.footnote.weight(.medium))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .card()
    }

    private var offsetDescription: String {
        if draftLyricOffset == 0 { return "原始時間" }
        let direction = draftLyricOffset > 0 ? "提早" : "延後"
        return "\(direction) \(String(format: "%.1f", abs(draftLyricOffset))) 秒"
    }

    private func applyOffset(_ offset: Double) {
        let adjusted = min(10, max(-10, offset))
        draftLyricOffset = adjusted
        Task { await monitor.setLyricOffset(adjusted) }
    }
}

private extension View {
    func card(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(.white.opacity(0.07), in: .rect(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
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
        VStack(spacing: 14) {
            if !lines.isEmpty {
                ForEach(visibleIndices, id: \.self) { index in
                    Text(lines[index].text)
                        .font(
                            index == currentIndex
                                ? .title2.weight(.bold) : .body.weight(.medium)
                        )
                        .foregroundStyle(
                            .white.opacity(
                                index == currentIndex
                                    ? 1 : max(0.22, 0.6 - Double(index - currentIndex) * 0.1))
                        )
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } else if !plainLines.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(plainLines.indices, id: \.self) { index in
                            Text(plainLines[index])
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxHeight: 340)
            } else {
                Text(fallback)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }
}
