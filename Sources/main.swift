import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var stateActor: AppStateActor!
    private var client: LyricsClient!
    private var bridge: MediaBridge!
    private var menuEngine: MenuBarEngine!
    private let pollingInterval: Double = 2.0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        stateActor = AppStateActor()
        client = LyricsClient()
        bridge = MediaBridge()
        menuEngine = MenuBarEngine()
        
        Task {
            await startPollingLoop()
        }
        
        Task {
            await startUpdateLoop()
        }
    }
    
    private func startPollingLoop() async {
        var currentTrackKey = ""
        
        while true {
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
                        
                        if let cached = await stateActor.getCachedLyrics(forKey: newTrackKey) {
                            await stateActor.setLyricsLoaded(cached, forKey: newTrackKey)
                        } else {
                            await stateActor.setLyricsLoading()
                            
                            Task {
                                var lyricsLines: [LyricLine]? = nil
                                
                                if track.player == "Music" {
                                    if let nativeText = await bridge.fetchAppleMusicLyrics() {
                                        print("Fetched native lyrics for \(track.title)")
                                        lyricsLines = client.parseLyrics(nativeText)
                                    } else {
                                        print("No native lyrics found for \(track.title)")
                                    }
                                }
                                
                                if lyricsLines == nil {
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
                                        print("Failed to fetch lyrics: \(error)")
                                        await stateActor.setLyricsError(error.localizedDescription, forKey: newTrackKey)
                                    }
                                }
                                
                                if let finalLyrics = lyricsLines {
                                    await stateActor.setLyricsLoaded(finalLyrics, forKey: newTrackKey)
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
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    private func startUpdateLoop() async {
        while true {
            let playbackInfo = await stateActor.getState()
            let lyricsInfo = await stateActor.getLyrics()
            
            menuEngine.update(
                state: playbackInfo.state,
                lyrics: lyricsInfo.lyrics,
                status: lyricsInfo.status,
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
