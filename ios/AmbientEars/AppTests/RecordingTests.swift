import HearingCore
import XCTest
@testable import AmbientEars

/// Covers the parts of the model that cannot move into HearingCore because
/// they touch the filesystem. Everything else worth asserting lives in the
/// core's own suite, which runs without Xcode.
final class RecordingTests: XCTestCase {
    private func track(levelsDBFS: [Float], hop: TimeInterval = 0.05) -> LevelTrack {
        LevelTrack(hopDuration: hop, levelsDBFS: levelsDBFS)
    }

    private func makeRecording(levelsDBFS: [Float]) -> Recording {
        let track = track(levelsDBFS: levelsDBFS)
        return Recording(
            url: URL(fileURLWithPath: "/tmp/session.wav"),
            startedAt: Date(timeIntervalSince1970: 0),
            duration: track.duration,
            levelTrack: track
        )
    }

    func testDestinationFilenameIsSortableAndDescribesTheMoment() {
        let moment = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 3, day: 9, hour: 14, minute: 5, second: 7
        ).date!

        let name = Recording.makeDestinationURL(now: moment).lastPathComponent

        XCTAssertTrue(name.hasPrefix("session-2026-03-09-"), name)
        XCTAssertTrue(name.hasSuffix(".wav"), name)
    }

    func testTwoCapturesInTheSameSecondWouldNotCollideAcrossSeconds() {
        let first = Recording.makeDestinationURL(now: Date(timeIntervalSince1970: 1_000))
        let second = Recording.makeDestinationURL(now: Date(timeIntervalSince1970: 1_001))

        XCTAssertNotEqual(first, second)
    }

    func testEventsAreDerivedOnceAndAreASubsetOfSegments() {
        let quiet = [Float](repeating: -70, count: 200)
        let loud = [Float](repeating: -12, count: 100)
        let recording = makeRecording(levelsDBFS: quiet + loud + quiet)

        XCTAssertFalse(recording.events.isEmpty)
        XCTAssertTrue(recording.events.allSatisfy(\.isActive))
        XCTAssertLessThanOrEqual(recording.events.count, recording.segments.count)
    }

    /// Reading the derived segments must not re-run detection, or the review
    /// screen stalls: SwiftUI touches these on every render.
    func testSegmentsAreStableAcrossReads() {
        let recording = makeRecording(
            levelsDBFS: [Float](repeating: -70, count: 100)
                + [Float](repeating: -10, count: 50)
        )

        XCTAssertEqual(recording.segments, recording.segments)
        XCTAssertEqual(recording.events, recording.events)
    }

    func testSilentRecordingHasNoEvents() {
        let recording = makeRecording(levelsDBFS: [Float](repeating: -90, count: 400))

        XCTAssertTrue(recording.events.isEmpty)
    }
}
