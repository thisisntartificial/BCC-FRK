import XCTest
@testable import HearingCore

final class PlaybackPlanTests: XCTestCase {
    private func plan(
        active: [(TimeInterval, TimeInterval)],
        duration: TimeInterval,
        config: PlaybackPlanConfig = .default
    ) -> PlaybackPlan {
        var segments: [ActivitySegment] = []
        var cursor: TimeInterval = 0

        for (start, end) in active {
            if start > cursor {
                segments.append(ActivitySegment(start: cursor, end: start, isActive: false))
            }
            segments.append(ActivitySegment(start: start, end: end, isActive: true))
            cursor = end
        }
        if cursor < duration {
            segments.append(ActivitySegment(start: cursor, end: duration, isActive: false))
        }

        return PlaybackPlan(segments: segments, duration: duration, config: config)
    }

    func testSilentRecordingPlaysEntirelyAtIdleRate() {
        let subject = plan(active: [], duration: 100)

        XCTAssertEqual(subject.rate(at: 0), subject.config.idleRate)
        XCTAssertEqual(subject.rate(at: 50), subject.config.idleRate)
        XCTAssertEqual(
            subject.compressedDuration,
            100 / TimeInterval(subject.config.idleRate),
            accuracy: 0.01
        )
    }

    func testConstantlyLoudRecordingPlaysAtNormalRate() {
        let subject = plan(active: [(0, 100)], duration: 100)

        XCTAssertEqual(subject.rate(at: 50), subject.config.activeRate)
        XCTAssertEqual(subject.compressedDuration, 100, accuracy: 0.01)
    }

    func testAudibleStretchPlaysAtNormalRate() {
        let subject = plan(active: [(40, 50)], duration: 100)

        XCTAssertEqual(subject.rate(at: 45), 1.0, accuracy: 0.0001)
    }

    func testFarFromAnySoundPlaysAtIdleRate() {
        let subject = plan(active: [(40, 50)], duration: 100)

        XCTAssertEqual(subject.rate(at: 5), subject.config.idleRate, accuracy: 0.0001)
        XCTAssertEqual(subject.rate(at: 90), subject.config.idleRate, accuracy: 0.0001)
    }

    /// The behaviour the whole design exists for: playback must already be at
    /// normal speed when a sound starts, or its opening is skipped over.
    func testPlaybackIsAtNormalRateBeforeEachSoundStarts() {
        let config = PlaybackPlanConfig(
            activeRate: 1,
            idleRate: 12,
            lookahead: 0.8,
            tail: 0.5,
            rampDuration: 0.3
        )
        let subject = plan(active: [(30, 33), (60, 62)], duration: 90, config: config)

        for onset in [30.0, 60.0] {
            XCTAssertEqual(subject.rate(at: onset), 1.0, accuracy: 0.0001)
            XCTAssertEqual(subject.rate(at: onset - config.lookahead), 1.0, accuracy: 0.0001)
            XCTAssertEqual(subject.rate(at: onset - 0.05), 1.0, accuracy: 0.0001)
        }
    }

    func testPlaybackStaysNormalThroughTheTailOfASound() {
        let config = PlaybackPlanConfig(idleRate: 10, lookahead: 0.5, tail: 0.7)
        let subject = plan(active: [(20, 25)], duration: 60, config: config)

        XCTAssertEqual(subject.rate(at: 25.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(subject.rate(at: 25.0 + config.tail - 0.01), 1.0, accuracy: 0.0001)
    }

    func testRateDecreasesMonotonicallyOnApproachToASound() {
        let subject = plan(active: [(30, 33)], duration: 60)

        var previous = Float.greatestFiniteMagnitude
        for step in stride(from: 28.0, through: 30.0, by: 0.02) {
            let rate = subject.rate(at: step)
            XCTAssertLessThanOrEqual(rate, previous + 0.0001)
            previous = rate
        }
    }

    func testRateNeverExceedsIdleOrFallsBelowActive() {
        let subject = plan(active: [(10, 12), (30, 31)], duration: 60)

        for step in stride(from: 0.0, through: 60.0, by: 0.05) {
            let rate = subject.rate(at: step)
            XCTAssertGreaterThanOrEqual(rate, subject.config.activeRate - 0.0001)
            XCTAssertLessThanOrEqual(rate, subject.config.idleRate + 0.0001)
        }
    }

    func testOverlappingLookaheadAndTailAreMerged() {
        // Two sounds close together should form one normal stretch rather than
        // dipping back to high speed for a fraction of a second between them.
        let config = PlaybackPlanConfig(lookahead: 1.0, tail: 1.0)
        let subject = plan(active: [(20, 21), (22, 23)], duration: 60, config: config)

        XCTAssertEqual(subject.normalIntervals.count, 1)
        XCTAssertEqual(subject.rate(at: 21.5), 1.0, accuracy: 0.0001)
    }

    func testLookaheadIsClampedAtTheStartOfTheRecording() {
        let config = PlaybackPlanConfig(lookahead: 5)
        let subject = plan(active: [(1, 3)], duration: 30, config: config)

        XCTAssertEqual(subject.normalIntervals.first?.lowerBound, 0)
        XCTAssertEqual(subject.rate(at: 0), 1.0, accuracy: 0.0001)
    }

    func testTailIsClampedAtTheEndOfTheRecording() {
        let config = PlaybackPlanConfig(tail: 10)
        let subject = plan(active: [(25, 29)], duration: 30, config: config)

        XCTAssertEqual(subject.normalIntervals.last?.upperBound, 30)
    }

    func testSkippingSilenceShortensTheSession() {
        let subject = plan(active: [(100, 110)], duration: 600)

        XCTAssertLessThan(subject.compressedDuration, 600)
        XCTAssertGreaterThan(subject.speedUpFactor, 3)
    }

    func testCompressedDurationNeverUndercountsAudibleTime() {
        // Every audible second is played at normal speed, so the session can
        // never be shorter than the total audible time.
        let audible: TimeInterval = 10 + 5
        let subject = plan(active: [(100, 110), (300, 305)], duration: 600)

        XCTAssertGreaterThan(subject.compressedDuration, audible)
    }

    func testHigherIdleRateProducesAShorterSession() {
        let slow = plan(
            active: [(100, 110)],
            duration: 600,
            config: PlaybackPlanConfig(idleRate: 4)
        )
        let fast = plan(
            active: [(100, 110)],
            duration: 600,
            config: PlaybackPlanConfig(idleRate: 16)
        )

        XCTAssertLessThan(fast.compressedDuration, slow.compressedDuration)
    }

    func testRatesAreClampedToWhatTheEngineSupports() {
        let config = PlaybackPlanConfig(activeRate: 0.01, idleRate: 500).clamped

        XCTAssertEqual(config.activeRate, PlaybackPlanConfig.supportedRateRange.lowerBound)
        XCTAssertEqual(config.idleRate, PlaybackPlanConfig.supportedRateRange.upperBound)
    }

    func testSlowMotionReviewIsSupported() {
        // Deliberately playing back below real time to study a faint sound.
        let config = PlaybackPlanConfig(activeRate: 0.5, idleRate: 8)
        let subject = plan(active: [(10, 20)], duration: 60, config: config)

        XCTAssertEqual(subject.rate(at: 15), 0.5, accuracy: 0.0001)
    }

    func testZeroDurationRecordingIsHandled() {
        let subject = plan(active: [], duration: 0)
        XCTAssertEqual(subject.compressedDuration, 0)
        XCTAssertEqual(subject.speedUpFactor, 1)
    }

    func testEndToEndFromRawAudio() {
        // Quiet room, one loud event, quiet again.
        let sampleRate: Double = 8000
        var builder = LevelTrackBuilder(sampleRate: sampleRate, hopDuration: 0.05)

        func append(amplitude: Float, seconds: Double) {
            let count = Int(sampleRate * seconds)
            var samples = [Float](repeating: 0, count: count)
            for index in 0 ..< count {
                let phase = 2 * Double.pi * 300 * Double(index) / sampleRate
                samples[index] = amplitude * Float(sin(phase))
            }
            builder.append(samples)
        }

        append(amplitude: 0.001, seconds: 20)
        append(amplitude: 0.4, seconds: 3)
        append(amplitude: 0.001, seconds: 20)

        let track = builder.finish()
        let segments = ActivityDetector().segments(for: track)
        let active = segments.filter(\.isActive)

        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active[0].start, 20, accuracy: 0.3)
        XCTAssertEqual(active[0].end, 23, accuracy: 0.3)

        let subject = PlaybackPlan(segments: segments, duration: track.duration)
        XCTAssertEqual(subject.rate(at: 20), 1.0, accuracy: 0.0001)
        XCTAssertEqual(subject.rate(at: 5), subject.config.idleRate, accuracy: 0.0001)
        XCTAssertLessThan(subject.compressedDuration, track.duration)
    }
}
