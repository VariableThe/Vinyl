import Foundation

public struct Track: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let player: String // "Spotify" or "Music"
    
    public var trackKey: String { "\(title)-\(artist)" }
}

public enum PlayerState: Equatable, Sendable {
    case notRunning
    case stopped
    case paused(track: Track, position: Double)
    case playing(track: Track, position: Double)
    
    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
}

public struct MediaBridge: Sendable {
    
    public enum BridgeError: LocalizedError {
        case appleScriptError(String)
        case invalidResponse
        case permissionDenied
        
        public var errorDescription: String? {
            switch self {
            case .appleScriptError(let msg): return "AppleScript Error: \(msg)"
            case .invalidResponse: return "Invalid response from player"
            case .permissionDenied: return "Permission denied. Grant Automation access."
            }
        }
    }
    
    public init() {}
    
    public func fetchCurrentState() async throws -> PlayerState {
        // Try Music first, then Spotify
        let musicState = try await fetchState(for: "Music")
        if musicState.isPlaying { return musicState }
        
        let spotifyState = try await fetchState(for: "Spotify")
        if spotifyState.isPlaying { return spotifyState }
        
        // If neither is playing, return the state of whichever is running/paused
        if case .paused = musicState { return musicState }
        if case .paused = spotifyState { return spotifyState }
        
        if case .stopped = musicState { return musicState }
        if case .stopped = spotifyState { return spotifyState }
        
        return .notRunning
    }
    
    private func fetchState(for appName: String) async throws -> PlayerState {
        let isRunningScript = """
        tell application "System Events"
            return exists (processes where name is "\(appName)")
        end tell
        """
        
        let isRunningStr = try await executeAppleScript(isRunningScript)
        guard isRunningStr.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return .notRunning
        }
        
        // Duration in Spotify is milliseconds, Music is seconds
        let durationConversion = appName == "Spotify" ? "(trackDuration / 1000.0)" : "trackDuration"
        
        let getPlaybackStateScript = """
        tell application "\(appName)"
            if player state is stopped then
                return "stopped"
            else
                set trackName to ""
                set trackArtist to ""
                set trackAlbum to ""
                set trackDuration to 0
                set trackPosition to 0
                set pState to "stopped"
                
                try
                    set trackName to name of current track
                end try
                try
                    set trackArtist to artist of current track
                end try
                try
                    set trackAlbum to album of current track
                end try
                try
                    set trackDuration to duration of current track
                end try
                try
                    set trackPosition to player position
                end try
                try
                    set pState to player state as string
                end try
                
                return trackName & "||" & trackArtist & "||" & trackAlbum & "||" & (\(durationConversion) as string) & "||" & (trackPosition as string) & "||" & pState
            end if
        end tell
        """
        
        let stateStr: String
        do {
            stateStr = try await executeAppleScript(getPlaybackStateScript).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return .notRunning
        }
        
        if stateStr == "stopped" {
            return .stopped
        }
        
        let parts = stateStr.components(separatedBy: "||")
        guard parts.count == 6 else { return .stopped }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        
        guard let durationSec = Double(parts[3]),
              let positionSec = Double(parts[4]) else {
            return .stopped
        }
        
        let pState = parts[5]
        
        let track = Track(title: title, artist: artist, album: album, duration: durationSec, player: appName)
        
        if pState == "playing" {
            return .playing(track: track, position: positionSec)
        } else {
            return .paused(track: track, position: positionSec)
        }
    }
    
    public func fetchAppleMusicLyrics() async -> String? {
        let script = """
        tell application "Music"
            if it is running then
                if player state is playing or player state is paused then
                    try
                        set l to lyrics of current track
                        if l is missing value then
                            return ""
                        else
                            return l
                        end if
                    on error
                        return ""
                    end try
                else
                    return ""
                end if
            else
                return ""
            end if
        end tell
        """
        if let result = try? await executeAppleScript(script), !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func executeAppleScript(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw BridgeError.appleScriptError("Could not initialize AppleScript.")
        }

        var errorInfo: NSDictionary? = nil
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo = errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? -1
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript Error"
            
            if code == -1743 {
                throw BridgeError.permissionDenied
            }
            throw BridgeError.appleScriptError("Code \(code): \(message)")
        }

        guard let stringValue = descriptor.stringValue else {
            throw BridgeError.invalidResponse
        }

        return stringValue
    }
}
