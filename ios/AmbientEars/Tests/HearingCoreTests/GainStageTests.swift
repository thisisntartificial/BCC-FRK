import XCTest
@testable import HearingCore

final class GainStageTests: XCTestCase {
    func testUnityGainIsSilentInDecibels() {
        XCTAssertEqual(GainStage.decibels(forMultiplier: 1), 0, accuracy: 0.001)
    }

    func testDoublingIsSixDecibels() {
        XCTAssertEqual(GainStage.decibels(forMultiplier: 2), 6.0206, accuracy: 0.001)
    }

    func testTenfoldIsTwentyDecibels() {
        XCTAssertEqual(GainStage.decibels(forMultiplier: 10), 20, accuracy: 0.001)
    }

    /// The whole point of the gain stage: asking for more must actually produce
    /// more, which the mixer's volume could not do above unity.
    func testGainIncreasesMonotonicallyAcrossTheRange() {
        let multipliers = stride(from: Float(1), through: 15, by: 0.5)
        var previous = -Float.infinity

        for multiplier in multipliers {
            let decibels = GainStage.decibels(forMultiplier: multiplier)
            XCTAssertGreaterThan(decibels, previous)
            previous = decibels
        }
    }

    func testGainNeverExceedsWhatTheStageAccepts() {
        for multiplier in [Float(15), 20, 100, 10_000] {
            XCTAssertLessThanOrEqual(
                GainStage.decibels(forMultiplier: multiplier),
                GainStage.maximumDB
            )
        }
    }

    /// The advertised range must be deliverable, or the slider would promise
    /// amplification that is silently dropped at the top end.
    func testTheTopOfTheRangeIsWithinTheCeiling() {
        let top = GainStage.decibels(
            forMultiplier: GainStage.supportedRange.upperBound
        )

        XCTAssertLessThanOrEqual(top, GainStage.maximumDB)
        XCTAssertGreaterThan(top, GainStage.maximumDB - 1)
    }

    func testAttenuationIsNotOfferedByTheAmplifier() {
        XCTAssertEqual(GainStage.decibels(forMultiplier: 0.5), 0, accuracy: 0.001)
    }

    func testDegenerateMultipliersAreTreatedAsUnity() {
        XCTAssertEqual(GainStage.decibels(forMultiplier: 0), 0)
        XCTAssertEqual(GainStage.decibels(forMultiplier: -3), 0)
        XCTAssertEqual(GainStage.decibels(forMultiplier: .nan), 0)
    }
}
