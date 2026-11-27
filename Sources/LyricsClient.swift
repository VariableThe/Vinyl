import Foundation

public struct LyricLine: Sendable, Codable {
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
    
    private struct LRCLyrics: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }
    
    public func fetchLyrics(
        track: String,
        artist: String,
        album: String,
        duration: Double
    ) async throws -> [LyricLine] {
        do {
            return try await fetchExactMatch(track: track, artist: artist, album: album, duration: duration)
        } catch URLError.fileDoesNotExist {
            return try await fetchSearchMatch(track: track, artist: artist)
        }
    }
    
    private func fetchSearchMatch(track: String, artist: String) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track) \(artist)")
        ]
        
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decodedArray = try JSONDecoder().decode([LRCLyrics].self, from: data)
        
        for decoded in decodedArray {
            if let synced = decoded.syncedLyrics, !synced.isEmpty {
                return parseLyrics(synced)
            } else if let plain = decoded.plainLyrics, !plain.isEmpty {
                return parseLyrics(plain)
            }
        }
        
        throw URLError(.fileDoesNotExist)
    }
    
    private func fetchExactMatch(
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
        let timestamp = /\[([0-9]+):([0-9]{1,2}(?:\.[0-9]+)?)\]/
        var synced: [LyricLine] = []

        for rawLine in rawLines {
            var rest = rawLine.trimmingCharacters(in: .whitespaces)[...]
            var times: [Double] = []
            // Repeated timestamps on one LRC line mark the same lyric at multiple positions.
            while let match = rest.prefixMatch(of: timestamp),
                  let minutes = Double(match.1), let seconds = Double(match.2), seconds < 60 {
                let time = minutes * 60 + seconds
                guard time.isFinite else { break }
                times.append(time)
                rest = rest[match.range.upperBound...]
            }
            guard !times.isEmpty else { continue }
            let text = rest.trimmingCharacters(in: .whitespaces)
            synced.append(contentsOf: times.map { LyricLine(timestamp: $0, text: text) })
        }

        // Section headings such as "[Verse 1: Duet]" are not timestamps.
        if !synced.isEmpty { return synced.sorted { $0.timestamp < $1.timestamp } }

        var plain = [LyricLine(timestamp: 0, text: "[Synced lyrics not available. Displaying plain text]")]
        for rawLine in rawLines {
            let text = rawLine.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { plain.append(LyricLine(timestamp: Double(plain.count) * 4, text: text)) }
        }
        return plain
    }
}
