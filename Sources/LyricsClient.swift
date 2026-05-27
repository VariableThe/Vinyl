import Foundation

public struct LyricLine: Sendable {
    public let timestamp: Double
    public let text: String
}

public enum LyricsStatus: Equatable, Sendable {
    case none
    case loading
    case loaded
    case notFound
    case error(String)
}

public struct LyricsClient: Sendable {
    private let userAgent = "MenuBarLyrics/1.0 (macOS; Swift)"
    
    public init() {}
    
    public func fetchLyrics(
        track: String,
        artist: String,
        album: String,
        duration: Double
    ) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        
        if !album.isEmpty {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration))))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 404 {
            throw URLError(.fileDoesNotExist) // Map 404 to not found
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct LRCLyrics: Decodable {
            let syncedLyrics: String?
            let plainLyrics: String?
        }
        
        let decoded = try JSONDecoder().decode(LRCLyrics.self, from: data)
        if let synced = decoded.syncedLyrics, !synced.isEmpty {
            return parseLyrics(synced)
        } else if let plain = decoded.plainLyrics, !plain.isEmpty {
            return parseLyrics(plain) // Will map plain to static lines
        } else {
            throw URLError(.fileDoesNotExist)
        }
    }
    
    public func parseLyrics(_ content: String) -> [LyricLine] {
        let rawLines = content.components(separatedBy: .newlines)
        var lines: [LyricLine] = []
        
        var isSynced = false
        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") && trimmed.contains("]") {
                if let closeBracket = trimmed.firstIndex(of: "]"),
                   trimmed[..<closeBracket].contains(":") {
                    isSynced = true
                    break
                }
            }
        }
        
        if isSynced {
            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("["), let closingBracketIndex = trimmed.firstIndex(of: "]") else {
                    continue
                }
                
                let timestampPart = trimmed[trimmed.index(after: trimmed.startIndex)..<closingBracketIndex]
                let lyricPart = trimmed[trimmed.index(after: closingBracketIndex)...].trimmingCharacters(in: .whitespaces)
                
                let timeComponents = timestampPart.split(separator: ":")
                guard timeComponents.count == 2 else { continue }
                
                guard let minutes = Double(timeComponents[0]),
                      let seconds = Double(timeComponents[1]) else {
                    continue
                }
                
                let totalSeconds = (minutes * 60.0) + seconds
                lines.append(LyricLine(timestamp: totalSeconds, text: lyricPart))
            }
        } else {
            lines.append(LyricLine(timestamp: 0.0, text: "[Synced lyrics not available. Displaying plain text]"))
            var validIndex = 0
            for rawLine in rawLines {
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    lines.append(LyricLine(timestamp: Double(validIndex + 1) * 4.0, text: trimmed))
                    validIndex += 1
                }
            }
        }
        
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
