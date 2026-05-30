import Foundation
import AppKit

public struct Track: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double
    public let player: String // "Spotify" or "Music"
    public let isShuffleOn: Bool
    public let isRepeatOn: Bool
    
    public var trackKey: String { "\(title)-\(artist)-\(album)-\(Int(duration))" }
    
    public init(title: String, artist: String, album: String, duration: Double, player: String, isShuffleOn: Bool = false, isRepeatOn: Bool = false) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.player = player
        self.isShuffleOn = isShuffleOn
        self.isRepeatOn = isRepeatOn
    }
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
        
        let isRunningStr = try executeAppleScript(isRunningScript)
        guard isRunningStr.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return .notRunning
        }
        
        
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
                    if player state is playing then
                        set pState to "playing"
                    else if player state is paused then
                        set pState to "paused"
                    end if
                end try
                
                set trackShuffle to false
                set trackRepeat to false
                try
                    if "\(appName)" is "Music" then
                        set trackShuffle to shuffle enabled
                        if song repeat is not off then
                            set trackRepeat to true
                        end if
                    else if "\(appName)" is "Spotify" then
                        set trackShuffle to shuffling
                        set trackRepeat to repeating
                    end if
                end try
                
                if "\(appName)" is "Spotify" then
                    set trackDuration to trackDuration / 1000.0
                end if
                
                return trackName & "||" & trackArtist & "||" & trackAlbum & "||" & (trackDuration as string) & "||" & (trackPosition as string) & "||" & pState & "||" & (trackShuffle as string) & "||" & (trackRepeat as string)
            end if
        end tell
        """
        
        let stateStr: String
        do {
            stateStr = try executeAppleScript(getPlaybackStateScript).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return .notRunning
        }
        
        return Self.parseState(from: stateStr, appName: appName)
    }
    
    public static func parseState(from stateStr: String, appName: String) -> PlayerState {
        if stateStr == "stopped" {
            return .stopped
        }
        
        let parts = stateStr.components(separatedBy: "||")
        guard parts.count >= 6 else { return .stopped }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        
        guard let durationSec = Double(parts[3]),
              let positionSec = Double(parts[4]) else {
            return .stopped
        }
        
        let pState = parts[5]
        
        let isShuffleOn = parts.count > 6 ? (parts[6] == "true") : false
        let isRepeatOn = parts.count > 7 ? (parts[7] == "true") : false
        
        let track = Track(title: title, artist: artist, album: album, duration: durationSec, player: appName, isShuffleOn: isShuffleOn, isRepeatOn: isRepeatOn)
        
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
        if let result = try? executeAppleScript(script), !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    public func playPause(player: String) async {
        let script = "tell application \"\(player)\" to playpause"
        _ = try? executeAppleScript(script)
    }
    
    public func skipToNextItem(player: String) async {
        let script = "tell application \"\(player)\" to next track"
        _ = try? executeAppleScript(script)
    }
    
    public func skipToPreviousItem(player: String) async {
        let script = "tell application \"\(player)\" to previous track"
        _ = try? executeAppleScript(script)
    }
    
    public func seekTo(position: Double, player: String) async {
        let script = "tell application \"\(player)\" to set player position to \(position)"
        _ = try? executeAppleScript(script)
    }
    
    public func skipForward(seconds: Double, player: String) async {
        let script = """
        tell application "\(player)"
            try
                set player position to (player position + \(seconds))
            end try
        end tell
        """
        _ = try? executeAppleScript(script)
    }

    public func skipBackward(seconds: Double, player: String) async {
        let script = """
        tell application "\(player)"
            try
                set currentPos to player position
                if currentPos < \(seconds) then
                    set player position to 0
                else
                    set player position to (currentPos - \(seconds))
                end if
            end try
        end tell
        """
        _ = try? executeAppleScript(script)
    }

    public func toggleRepeat(player: String) async {
        let script = """
        tell application "\(player)"
            if "\(player)" is "Music" then
                try
                    if song repeat is all then
                        set song repeat to off
                    else
                        set song repeat to all
                    end if
                end try
            else if "\(player)" is "Spotify" then
                try
                    set repeating to not repeating
                end try
            end if
        end tell
        """
        _ = try? executeAppleScript(script)
    }

    public func toggleShuffle(player: String) async {
        let script = """
        tell application "\(player)"
            if "\(player)" is "Music" then
                try
                    set shuffle enabled to not shuffle enabled
                end try
            else if "\(player)" is "Spotify" then
                try
                    set shuffling to not shuffling
                end try
            end if
        end tell
        """
        _ = try? executeAppleScript(script)
    }
    
    public func fetchArtwork(for player: String) async -> Data? {
        if player == "Music" {
            let scriptStr = """
            tell application "Music"
                try
                    if player state is playing or player state is paused then
                        return raw data of artwork 1 of current track
                    end if
                end try
            end tell
            """
            if let script = NSAppleScript(source: scriptStr) {
                var error: NSDictionary?
                let desc = script.executeAndReturnError(&error)
                let data = desc.data
                if data.count > 0 {
                    return data
                }
            }
        } else if player == "Spotify" {
            let scriptStr = """
            tell application "Spotify"
                try
                    if player state is playing or player state is paused then
                        return artwork url of current track
                    end if
                end try
            end tell
            """
            if let script = NSAppleScript(source: scriptStr) {
                var error: NSDictionary?
                let desc = script.executeAndReturnError(&error)
                if let urlString = desc.stringValue, let url = URL(string: urlString) {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return data
                    } catch {
                        return nil
                    }
                }
            }
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
