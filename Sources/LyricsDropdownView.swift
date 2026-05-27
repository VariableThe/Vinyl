import SwiftUI

public struct LyricsDropdownView: View {
    public let currentTrack: Track?
    public let isPlaying: Bool
    public let lyrics: [LyricLine]
    public let currentPosition: Double
    public let bridge: MediaBridge
    
    public init(currentTrack: Track?, isPlaying: Bool, lyrics: [LyricLine], currentPosition: Double, bridge: MediaBridge) {
        self.currentTrack = currentTrack
        self.isPlaying = isPlaying
        self.lyrics = lyrics
        self.currentPosition = currentPosition
        self.bridge = bridge
    }
    
    @State private var isDragging: Bool = false
    @State private var localPosition: Double = 0.0
    
    private var seekBinding: Binding<Double> {
        Binding<Double>(
            get: {
                isDragging ? localPosition : currentPosition
            },
            set: { newValue in
                localPosition = newValue
            }
        )
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(currentTrack?.title ?? "Not Playing")
                        .font(.headline)
                        .lineLimit(1)
                    Text(currentTrack?.artist ?? "Artist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                
                // Controls
                HStack(spacing: 12) {
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipToPreviousItem(player: player) }
                        }
                    }) {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.playPause(player: player) }
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipToNextItem(player: player) }
                        }
                    }) {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            
            // Seek Bar
            if let track = currentTrack, track.duration > 0 {
                HStack {
                    Text(formatTime(seekBinding.wrappedValue))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    
                    Slider(value: seekBinding, in: 0...track.duration) { editing in
                        isDragging = editing
                        if !editing {
                            Task { await bridge.seekTo(position: localPosition, player: track.player) }
                        }
                    }
                    .controlSize(.small)
                    
                    Text(formatTime(track.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            Divider()
            
            // Lyrics
            if lyrics.isEmpty {
                VStack {
                    Spacer()
                    Text("No lyrics available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(lyrics.enumerated()), id: \.offset) { index, line in
                                let isActive = isActiveLine(index: index)
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(size: 14, weight: isActive ? .bold : .regular))
                                    .foregroundColor(isActive ? .primary : .secondary)
                                    .id(index)
                                    .animation(.easeInOut, value: isActive)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: currentPosition) { _ in
                        if let activeIndex = activeLyricIndex() {
                            withAnimation {
                                proxy.scrollTo(activeIndex, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if let activeIndex = activeLyricIndex() {
                            proxy.scrollTo(activeIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
    }
    
    private func isActiveLine(index: Int) -> Bool {
        return index == activeLyricIndex()
    }
    
    private func activeLyricIndex() -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var activeIndex: Int? = nil
        let pos = isDragging ? localPosition : currentPosition
        for (index, line) in lyrics.enumerated() {
            if line.timestamp <= pos {
                activeIndex = index
            } else {
                break
            }
        }
        return activeIndex
    }
    
    private func formatTime(_ time: Double) -> String {
        if time < 0 { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
