import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var stateActor: AppStateActor!
    private var client: LyricsClient!
    private var bridge: MediaBridge!
    private var menuEngine: MenuBarEngine!
    
    private var pollingTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        stateActor = AppStateActor()
        client = LyricsClient()
        bridge = MediaBridge()
        menuEngine = MenuBarEngine(bridge: bridge)
        
        pollingTask = Task {
            await startPollingLoop()
        }
        
        updateTask = Task {
            await startUpdateLoop()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        pollingTask?.cancel()
        updateTask?.cancel()
    }
    
    private func startPollingLoop() async {
        var currentTrackKey = ""
        
        while true {
            guard !Task.isCancelled else { break }
            do {
                let state = try await bridge.fetchCurrentState()
                await stateActor.updatePlayback(state: state)
                
                let track: Track?
                switch state {
                case .playing(let t, _), .paused(let t, _):
                    track = t
                default:
                    track = nil
                }
                
                if let track = track {
                    let newTrackKey = track.trackKey
                    if newTrackKey != currentTrackKey && !newTrackKey.isEmpty {
                        currentTrackKey = newTrackKey
                        print("Now playing: \(track.title) by \(track.artist)")
                        
                        artworkTask?.cancel()
                        artworkTask = Task {
                            let artworkData = await bridge.fetchArtwork(for: track.player)
                            guard !Task.isCancelled else { return }
                            await stateActor.setArtwork(artworkData)
                        }
                        
                        if let cached = await stateActor.getCachedLyrics(forKey: newTrackKey) {
                            await stateActor.setLyricsLoaded(cached, forKey: newTrackKey)
                        } else {
                            await stateActor.setLyricsLoading()
                            
                            Task {
                                var lyricsLines: [LyricLine]? = nil
                                var fetchError: Error? = nil
                                
                                // 1. Try LRCLIB
                                do {
                                    print("Fetching lrclib lyrics for \(track.title)")
                                    lyricsLines = try await client.fetchLyrics(
                                        track: track.title,
                                        artist: track.artist,
                                        album: track.album,
                                        duration: track.duration
                                    )
                                    print("Successfully fetched lrclib lyrics")
                                } catch {
                                    print("Failed to fetch lrclib lyrics: \(error)")
                                    fetchError = error
                                }
                                
                                // 2. Fallback to Apple Music Native Offline
                                if lyricsLines == nil && track.player == "Music" {
                                    if let nativeText = await bridge.fetchAppleMusicLyrics() {
                                        print("Fallback: Fetched native lyrics for \(track.title)")
                                        lyricsLines = client.parseLyrics(nativeText)
                                    } else {
                                        print("Fallback: No native lyrics found for \(track.title)")
                                    }
                                }
                                
                                if let finalLyrics = lyricsLines {
                                    await stateActor.setLyricsLoaded(finalLyrics, forKey: newTrackKey)
                                } else if let error = fetchError {
                                    await stateActor.setLyricsError(error.localizedDescription, forKey: newTrackKey)
                                } else {
                                    await stateActor.setLyricsError("Lyrics not found", forKey: newTrackKey)
                                }
                            }
                        }
                    }
                } else {
                    currentTrackKey = ""
                }
            } catch {
                print("Polling error: \(error)")
                await stateActor.updatePlayback(state: .notRunning)
            }
            
            do {
                var currentInterval = UserDefaults.standard.double(forKey: "pollingInterval")
                if currentInterval < 1.0 { currentInterval = 2.0 } // default if not set
                try await Task.sleep(nanoseconds: UInt64(currentInterval * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    private func startUpdateLoop() async {
        while true {
            guard !Task.isCancelled else { break }
            let playbackInfo = await stateActor.getState()
            let lyricsInfo = await stateActor.getLyrics()
            let artworkData = await stateActor.getArtwork()
            
            let artworkImage = artworkData != nil ? NSImage(data: artworkData!) : nil
            
            menuEngine.update(
                state: playbackInfo.state,
                lyrics: lyricsInfo.lyrics,
                status: lyricsInfo.status,
                artwork: artworkImage,
                lastUpdated: playbackInfo.lastUpdated
            )
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            } catch {
                break
            }
        }
    }
}

@main
struct VinylApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
