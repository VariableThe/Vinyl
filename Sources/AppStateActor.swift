import Foundation

public actor AppStateActor {
    private var state: PlayerState = .notRunning
    private var lastUpdated: Date = Date()
    private var currentLyrics: [LyricLine] = []
    private var lyricsStatus: LyricsStatus = .none
    
    // Cache for lyrics so we don't refetch on pause/play
    private var lyricsCache: [String: [LyricLine]] = [:]
    private let cacheFileURL: URL
    
    public init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirURL = appSupportURL.appendingPathComponent("Vinyl", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirURL.path) {
            try? fileManager.createDirectory(at: appDirURL, withIntermediateDirectories: true)
        }
        
        let url = appDirURL.appendingPathComponent("lyrics_cache.json")
        cacheFileURL = url
        
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [LyricLine]].self, from: data) {
            lyricsCache = decoded
        }
    }
    
    private var saveTask: Task<Void, Never>?

    private func saveCacheToDisk() {
        let cacheToSave = lyricsCache
        let url = cacheFileURL
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(cacheToSave) {
                try? data.write(to: url)
            }
        }
    }
    
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
        saveCacheToDisk()
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

