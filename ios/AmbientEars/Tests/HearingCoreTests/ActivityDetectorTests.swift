import XCTest
@testable import HearingCore

/// Builds a track from a description of alternating quiet and loud stretches.
private func track(
    hop: TimeInterval = 0.1,
    _ spans: [(level: Float, seconds: TimeInterval)]
) -> LevelTrack {
    var levels: [Float] = []
    for span in spans {
        let count = Int((span.seconds / hop).rounded())
        levels.append(contentsOf: [Float](repeating: span.level, count: count))
    }
    return LevelTrack(hopDuration: hop, levelsDBFS: levels)
}

final class ActivityDetectorTests: XCTestCase {
    func testSilenceOnlyRecordingHasNoActivity() {
        let detector = ActivityDetector()
        let segments = detector.segments(for: track([(-80, 10)]))

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.isActive, false)
    }

    func testFindsASingleBurst() {
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-70, 5), (-20, 2), (-70, 5)])
        )

        let active = segments.filter(\.isActive)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active[0].start, 5.0, accuracy: 0.15)
        XCTAssertEqual(active[0].end, 7.0, accuracy: 0.15)
    }

    func testFindsMultipleSeparatedBursts() {
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-70, 5), (-20, 2), (-70, 5), (-25, 3), (-70, 4)])
        )

        XCTAssertEqual(segments.filter(\.isActive).count, 2)
    }

    func testSegmentsTileTheWholeRecordingWithoutGaps() {
        let detector = ActivityDetector()
        let source = track([(-70, 3), (-20, 1), (-70, 3), (-20, 1), (-70, 3)])
        let segments = detector.segments(for: source)

        XCTAssertEqual(segments.first?.start, 0)
        XCTAssertEqual(segments.last?.end ?? 0, source.duration, accuracy: 0.001)

        for (previous, next) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(previous.end, next.start, accuracy: 0.0001)
            XCTAssertNotEqual(previous.isActive, next.isActive)
        }
    }

    func testShortClickIsIgnored() {
        // A 0.1s tick is shorter than minActiveDuration and should not become
        // an event, otherwise a whole night of recording is unreviewable.
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-70, 5), (-20, 0.1), (-70, 5)])
        )

        XCTAssertTrue(segments.filter(\.isActive).isEmpty)
    }

    func testBriefPauseDoesNotSplitOneEvent() {
        // A short gap mid-sentence must not produce two separate events.
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-70, 4), (-20, 2), (-70, 0.3), (-20, 2), (-70, 4)])
        )

        XCTAssertEqual(segments.filter(\.isActive).count, 1)
    }

    func testLongPauseDoesSplitEvents() {
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-70, 4), (-20, 2), (-70, 3), (-20, 2), (-70, 4)])
        )

        XCTAssertEqual(segments.filter(\.isActive).count, 2)
    }

    func testNoiseFloorAdaptsToTheRecording() {
        let detector = ActivityDetector()
        let quiet = track([(-80, 10)])
        let noisy = track([(-40, 10)])

        XCTAssertLessThan(
            detector.noiseFloorDBFS(for: quiet),
            detector.noiseFloorDBFS(for: noisy)
        )
    }

    func testDetectionWorksAgainstALoudNoiseFloor() {
        // Recording beside a fan: the floor is high, but speech still rises
        // above it and must be found.
        let detector = ActivityDetector()
        let segments = detector.segments(
            for: track([(-35, 5), (-15, 2), (-35, 5)])
        )

        XCTAssertEqual(segments.filter(\.isActive).count, 1)
    }

    func testHysteresisPreventsChatterAtTheThreshold() {
        // Level oscillating either side of the open threshold must not produce
        // a long run of alternating segments.
        let hop: TimeInterval = 0.1
        var levels: [Float] = [Float](repeating: -70, count: 30)
        for index in 0 ..< 60 {
            levels.append(index.isMultiple(of: 2) ? -58 : -62)
        }
        levels.append(contentsOf: [Float](repeating: -70, count: 30))

        let detector = ActivityDetector()
        let segments = detector.segments(
            for: LevelTrack(hopDuration: hop, levelsDBFS: levels)
        )

        XCTAssertLessThanOrEqual(segments.count, 5)
    }

    func testEmptyTrackYieldsNoSegments() {
        let detector = ActivityDetector()
        XCTAssertTrue(detector.segments(for: LevelTrack(hopDuration: 0.1, levelsDBFS: [])).isEmpty)
    }

    func testAbsoluteFloorStopsSilenceLookingLikeSound() {
        // In a dead-quiet room the relative floor alone would treat the faintest
        // fluctuation as an event.
        let detector = ActivityDetector()
        var levels = [Float](repeating: -100, count: 100)
        for index in 40 ..< 60 { levels[index] = -95 }

        let segments = detector.segments(
            for: LevelTrack(hopDuration: 0.1, levelsDBFS: levels)
        )

        XCTAssertTrue(segments.filter(\.isActive).isEmpty)
    }
}
