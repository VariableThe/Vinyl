import Foundation

public actor AppStateActor {
    private var state: PlayerState = .notRunning
    private var lastUpdated: Date = Date()
    private var currentLyrics: [LyricLine] = []
    private var lyricsStatus: LyricsStatus = .none
    
    // Cache for lyrics so we don't refetch on pause/play
    private var lyricsCache: [String: [LyricLine]] = [:]
    
    public init() {}
    
    public func updatePlayback(state newState: PlayerState) {
        self.state = newState
        self.lastUpdated = Date()
    }
    
    public func setLyricsLoading() {
        self.lyricsStatus = .loading
        self.currentLyrics = []
    }
    
    public func setLyricsLoaded(_ lyrics: [LyricLine], forKey key: String) {
        self.lyricsStatus = .loaded
        self.currentLyrics = lyrics
        self.lyricsCache[key] = lyrics
    }
    
    public func setLyricsNotFound(forKey key: String) {
        self.lyricsStatus = .notFound
        self.currentLyrics = []
    }
    
    public func setLyricsError(_ msg: String, forKey key: String) {
        self.lyricsStatus = .error(msg)
        self.currentLyrics = []
    }
    
    public func getCachedLyrics(forKey key: String) -> [LyricLine]? {
        return lyricsCache[key]
    }
    
    public func getState() -> (state: PlayerState, lastUpdated: Date) {
        return (state, lastUpdated)
    }
    
    public func getLyrics() -> (lyrics: [LyricLine], status: LyricsStatus) {
        return (currentLyrics, lyricsStatus)
    }
}
