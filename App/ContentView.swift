import SwiftUI

struct ContentView: View {
    @Bindable var monitor: AppleMusicMonitor
    @State private var draftLyricOffset: Double = 0
    @State private var liveActivityActive = false

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
                        playbackTime: max(0, monitor.playbackTime + monitor.lyricOffset),
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

                    VStack(spacing: 10) {
                        HStack {
                            Text("歌詞時間調整")
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
                        .font(.caption)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)

                    if let track = monitor.track {
                        VStack(spacing: 8) {
                            HStack {
                                Button(liveActivityActive ? "即時動態已開啟" : "開始即時動態") {
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
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(liveActivityActive || (monitor.lyrics.isEmpty && monitor.plainLyrics.isEmpty))

                                Button("結束即時動態") {
                                    Task {
                                        await LiveActivityManager.shared.end()
                                        liveActivityActive = false
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(!liveActivityActive)
                            }
                            Text(liveActivityActive
                                 ? "已顯示於鎖定畫面與動態島。App 進入背景後可能停止更新；重新開啟可恢復歌詞。"
                                 : "開啟後會顯示於鎖定畫面與動態島。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
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
        .onAppear {
            draftLyricOffset = monitor.lyricOffset
            liveActivityActive = LiveActivityManager.shared.isActive
        }
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
