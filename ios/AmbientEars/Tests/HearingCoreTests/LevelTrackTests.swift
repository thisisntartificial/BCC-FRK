import XCTest
@testable import HearingCore

final class LevelTrackTests: XCTestCase {
    func testBuilderProducesOneHopPerInterval() {
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 0.5, count: 1000))
        let track = builder.finish()

        XCTAssertEqual(track.levelsDBFS.count, 10)
        XCTAssertEqual(track.duration, 1.0, accuracy: 0.0001)
    }

    func testBuilderCarriesRemainderAcrossBuffers() {
        // Hardware delivers buffers that do not divide evenly into hops, so
        // leftover samples must survive until the next append.
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 0.5, count: 30))
        XCTAssertEqual(builder.hopCount, 0)

        builder.append([Float](repeating: 0.5, count: 80))
        XCTAssertEqual(builder.hopCount, 1)

        builder.append([Float](repeating: 0.5, count: 90))
        XCTAssertEqual(builder.hopCount, 2)
    }

    func testSilenceIsReportedAtFloor() {
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 0, count: 1000))
        let track = builder.finish()

        XCTAssertTrue(track.levelsDBFS.allSatisfy { $0 == LevelTrack.silenceDBFS })
    }

    func testFullScaleSignalIsNearZeroDBFS() {
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 1.0, count: 1000))
        let track = builder.finish()

        for level in track.levelsDBFS {
            XCTAssertEqual(level, 0, accuracy: 0.001)
        }
    }

    func testLouderAudioMeasuresHigher() {
        func level(of amplitude: Float) -> Float {
            var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
            builder.append([Float](repeating: amplitude, count: 100))
            return builder.finish().levelsDBFS[0]
        }

        XCTAssertLessThan(level(of: 0.01), level(of: 0.1))
        XCTAssertLessThan(level(of: 0.1), level(of: 1.0))
    }

    func testHalvingAmplitudeDropsSixDecibels() {
        func level(of amplitude: Float) -> Float {
            var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
            builder.append([Float](repeating: amplitude, count: 100))
            return builder.finish().levelsDBFS[0]
        }

        XCTAssertEqual(level(of: 0.5) - level(of: 0.25), 6.02, accuracy: 0.05)
    }

    func testFinishEmitsTrailingPartialHop() {
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 0.5, count: 150))
        let track = builder.finish()

        XCTAssertEqual(track.levelsDBFS.count, 2)
    }

    func testPercentilePicksExpectedValue() {
        let track = LevelTrack(
            hopDuration: 0.1,
            levelsDBFS: [-80, -70, -60, -50, -40]
        )

        XCTAssertEqual(track.percentileDBFS(0), -80, accuracy: 0.001)
        XCTAssertEqual(track.percentileDBFS(0.5), -60, accuracy: 0.001)
        XCTAssertEqual(track.percentileDBFS(1), -40, accuracy: 0.001)
    }

    func testSnapshotDoesNotConsumePendingAudio() {
        var builder = LevelTrackBuilder(sampleRate: 1000, hopDuration: 0.1)
        builder.append([Float](repeating: 0.5, count: 250))

        XCTAssertEqual(builder.snapshot().levelsDBFS.count, 2)
        builder.append([Float](repeating: 0.5, count: 50))
        XCTAssertEqual(builder.snapshot().levelsDBFS.count, 3)
    }

    func testEmptyTrackHasNoDuration() {
        let track = LevelTrack(hopDuration: 0.05, levelsDBFS: [])
        XCTAssertTrue(track.isEmpty)
        XCTAssertEqual(track.duration, 0)
    }
}
