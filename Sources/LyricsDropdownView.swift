import SwiftUI

public struct LyricsDropdownView: View {
    public let currentTrack: Track?
    public let isPlaying: Bool
    public let lyrics: [LyricLine]
    public let currentPosition: Double
    public let bridge: MediaBridge
    public let artwork: NSImage?
    
    public init(currentTrack: Track?, isPlaying: Bool, lyrics: [LyricLine], currentPosition: Double, bridge: MediaBridge, artwork: NSImage?) {
        self.currentTrack = currentTrack
        self.isPlaying = isPlaying
        self.lyrics = lyrics
        self.currentPosition = currentPosition
        self.bridge = bridge
        self.artwork = artwork
    }
    
    @AppStorage("enableBlurredBackground") private var enableBlurredBackground: Bool = true
    @AppStorage("enableHeaderAlbumArt") private var enableHeaderAlbumArt: Bool = false
    @State private var isDragging: Bool = false
    @State private var localPosition: Double = 0.0
    @State private var optimisticShuffleState: Bool? = nil
    @State private var optimisticRepeatState: Bool? = nil
    
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
                if enableHeaderAlbumArt, let artwork = artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                }
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
                HStack(spacing: 8) {
                    Button(action: {
                        if let player = currentTrack?.player {
                            let currentState = currentTrack?.isShuffleOn ?? false
                            optimisticShuffleState = !currentState
                            Task {
                                await bridge.toggleShuffle(player: player)
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                optimisticShuffleState = nil
                            }
                        }
                    }) {
                        let isOn = optimisticShuffleState ?? (currentTrack?.isShuffleOn ?? false)
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                            .foregroundColor(isOn ? .accentColor : .primary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipBackward(seconds: 10, player: player) }
                        }
                    }) {
                        Image(systemName: "gobackward.10")
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipToPreviousItem(player: player) }
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.playPause(player: player) }
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipToNextItem(player: player) }
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if let player = currentTrack?.player {
                            Task { await bridge.skipForward(seconds: 10, player: player) }
                        }
                    }) {
                        Image(systemName: "goforward.10")
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        if let player = currentTrack?.player {
                            let currentState = currentTrack?.isRepeatOn ?? false
                            optimisticRepeatState = !currentState
                            Task {
                                await bridge.toggleRepeat(player: player)
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                optimisticRepeatState = nil
                            }
                        }
                    }) {
                        let isOn = optimisticRepeatState ?? (currentTrack?.isRepeatOn ?? false)
                        Image(systemName: "repeat")
                            .font(.system(size: 12))
                            .foregroundColor(isOn ? .accentColor : .primary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
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
        .background(
            Group {
                if enableBlurredBackground, let artwork = artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 20)
                        .opacity(0.4)
                } else {
                    Color.clear
                }
            }
        )
        .frame(width: 380, height: 400)
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
