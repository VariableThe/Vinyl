import XCTest
@testable import Vinyl

final class VinylTests: XCTestCase {
    func testParseLyricsSynced() {
        let client = LyricsClient()
        let lyrics = """
        [00:01.00] Line 1
        [00:05.50] Line 2
        """
        let parsed = client.parseLyrics(lyrics)
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].timestamp, 1.0)
        XCTAssertEqual(parsed[0].text, "Line 1")
        XCTAssertEqual(parsed[1].timestamp, 5.5)
        XCTAssertEqual(parsed[1].text, "Line 2")
    }

    func testParseLyricsPlain() {
        let client = LyricsClient()
        let lyrics = """
        Line 1
        Line 2
        """
        let parsed = client.parseLyrics(lyrics)
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed[0].text, "[Synced lyrics not available. Displaying plain text]")
        XCTAssertEqual(parsed[1].timestamp, 4.0)
        XCTAssertEqual(parsed[1].text, "Line 1")
        XCTAssertEqual(parsed[2].timestamp, 8.0)
        XCTAssertEqual(parsed[2].text, "Line 2")
    }

    func testMediaBridgeParseStatePlaying() {
        let stateStr = "Song Name||Artist Name||Album Name||120.5||60.2||playing"
        let state = MediaBridge.parseState(from: stateStr, appName: "Music")
        if case let .playing(track, position) = state {
            XCTAssertEqual(track.title, "Song Name")
            XCTAssertEqual(track.artist, "Artist Name")
            XCTAssertEqual(track.album, "Album Name")
            XCTAssertEqual(track.duration, 120.5)
            XCTAssertEqual(track.player, "Music")
            XCTAssertEqual(position, 60.2)
        } else {
            XCTFail("Expected playing state")
        }
    }

    func testMediaBridgeParseStateStopped() {
        let state = MediaBridge.parseState(from: "stopped", appName: "Spotify")
        XCTAssertEqual(state, .stopped)
    }

    func testLyricLineCodable() throws {
        let line1 = LyricLine(timestamp: 12.5, text: "Hello World")
        let line2 = LyricLine(timestamp: 20.0, text: "Testing Codable")
        let cache: [String: [LyricLine]] = ["Track1": [line1, line2]]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(cache)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: [LyricLine]].self, from: data)
        
        XCTAssertEqual(decoded.keys.count, 1)
        XCTAssertEqual(decoded["Track1"]?.count, 2)
        XCTAssertEqual(decoded["Track1"]?[0].timestamp, 12.5)
        XCTAssertEqual(decoded["Track1"]?[0].text, "Hello World")
        XCTAssertEqual(decoded["Track1"]?[1].timestamp, 20.0)
        XCTAssertEqual(decoded["Track1"]?[1].text, "Testing Codable")
    }
}
