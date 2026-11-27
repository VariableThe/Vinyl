import Foundation
import XCTest
@testable import Vinyl

final class AppStateActorTests: XCTestCase {
    @MainActor
    func testCachedTrackIgnoresLateLyricsAndErrorsFromPriorTrack() async throws {
        let previous = track("Previous")
        let current = track("Current")
        let cached = [LyricLine(timestamp: 0, text: "Cached current lyrics")]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cacheURL = directory.appendingPathComponent("lyrics_cache.json")
        try JSONEncoder().encode([current.trackKey: cached]).write(to: cacheURL)
        let actor = AppStateActor(cacheFileURL: cacheURL)

        await actor.updatePlayback(state: .playing(track: previous, position: 0))
        await actor.setLyricsLoading()
        await actor.updatePlayback(state: .paused(track: current, position: 0))
        let cachedResult = await actor.getCachedLyrics(forKey: current.trackKey)
        let currentLyrics = try XCTUnwrap(cachedResult)
        await actor.setLyricsLoaded(currentLyrics, forKey: current.trackKey)

        await actor.setLyricsLoaded([LyricLine(timestamp: 0, text: "Previous lyrics")], forKey: previous.trackKey)
        let afterLateResult = await actor.getLyrics()
        XCTAssertEqual(afterLateResult.status, .loaded)
        XCTAssertEqual(afterLateResult.lyrics.map(\.text), ["Cached current lyrics"])
        let staleCache = await actor.getCachedLyrics(forKey: previous.trackKey)
        XCTAssertNil(staleCache)

        await actor.setLyricsError("Late network error", forKey: previous.trackKey)
        await actor.setLyricsNotFound(forKey: previous.trackKey)
        let afterLateErrors = await actor.getLyrics()
        XCTAssertEqual(afterLateErrors.status, .loaded)
        XCTAssertEqual(afterLateErrors.lyrics.map(\.text), ["Cached current lyrics"])
    }

    @MainActor
    func testStoppedPlaybackIgnoresLateResult() async {
        let previous = track("Previous")
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("lyrics_cache.json")
        let actor = AppStateActor(cacheFileURL: cacheURL)
        await actor.updatePlayback(state: .playing(track: previous, position: 0))
        await actor.updatePlayback(state: .stopped)
        await actor.setLyricsLoaded([LyricLine(timestamp: 0, text: "Stale lyrics")], forKey: previous.trackKey)
        let snapshot = await actor.getLyrics()
        XCTAssertEqual(snapshot.status, .none)
        XCTAssertTrue(snapshot.lyrics.isEmpty)
    }

    private func track(_ title: String) -> Track {
        Track(title: title, artist: "Artist", album: "Album", duration: 120, player: "Music")
    }
}
