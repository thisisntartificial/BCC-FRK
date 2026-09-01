import XCTest
@testable import HearingCore

final class EventNavigatorTests: XCTestCase {
    private let lookahead: TimeInterval = 0.5

    private func segments() -> [ActivitySegment] {
        [
            ActivitySegment(start: 0, end: 10, isActive: false),
            ActivitySegment(start: 10, end: 12, isActive: true),
            ActivitySegment(start: 12, end: 30, isActive: false),
            ActivitySegment(start: 30, end: 33, isActive: true),
            ActivitySegment(start: 33, end: 60, isActive: false),
        ]
    }

    func testNextTargetLandsBeforeTheEventNotOnIt() {
        let target = EventNavigator.nextTarget(
            after: 0,
            in: segments(),
            lookahead: lookahead
        )

        XCTAssertEqual(try XCTUnwrap(target), 9.5, accuracy: 0.001)
    }

    func testNextTargetSkipsTheEventCurrentlyPlaying() {
        let target = EventNavigator.nextTarget(
            after: 10.5,
            in: segments(),
            lookahead: lookahead
        )

        XCTAssertEqual(try XCTUnwrap(target), 29.5, accuracy: 0.001)
    }

    func testNextTargetIsNilPastTheFinalEvent() {
        XCTAssertNil(
            EventNavigator.nextTarget(after: 40, in: segments(), lookahead: lookahead)
        )
    }

    func testNextTargetIgnoresSilentStretches() {
        let onlySilence = [ActivitySegment(start: 0, end: 60, isActive: false)]

        XCTAssertNil(
            EventNavigator.nextTarget(after: 0, in: onlySilence, lookahead: lookahead)
        )
    }

    func testNextTargetNeverGoesNegative() {
        let immediate = [ActivitySegment(start: 0.1, end: 2, isActive: true)]

        let target = EventNavigator.nextTarget(
            after: -1,
            in: immediate,
            lookahead: 5
        )

        XCTAssertEqual(try XCTUnwrap(target), 0)
    }

    func testPreviousTargetReturnsToTheEventJustHeard() {
        let target = EventNavigator.previousTarget(
            before: 35,
            in: segments(),
            lookahead: lookahead
        )

        XCTAssertEqual(target, 29.5, accuracy: 0.001)
    }

    /// Pressing back a moment into an event should replay that event, not the
    /// one before it.
    func testPreviousTargetRepeatsTheCurrentEventShortlyAfterItStarts() {
        let target = EventNavigator.previousTarget(
            before: 31.5,
            in: segments(),
            lookahead: lookahead
        )

        XCTAssertEqual(target, 29.5, accuracy: 0.001)
    }

    func testPreviousTargetFallsBackToTheStart() {
        let target = EventNavigator.previousTarget(
            before: 5,
            in: segments(),
            lookahead: lookahead
        )

        XCTAssertEqual(target, 0)
    }
}

final class RateResolverTests: XCTestCase {
    func testSmartModeScalesThePlannedRate() {
        let rate = RateResolver.resolve(
            planned: 8,
            manualRate: 1,
            isSmartModeEnabled: true
        )

        XCTAssertEqual(rate, 8, accuracy: 0.001)
    }

    /// The listener's preference multiplies the plan, so slowing down for
    /// events still happens when they ask for a gentler skim.
    func testManualRateScalesRatherThanReplacesThePlan() {
        let duringSound = RateResolver.resolve(
            planned: 1,
            manualRate: 0.5,
            isSmartModeEnabled: true
        )
        let duringSilence = RateResolver.resolve(
            planned: 12,
            manualRate: 0.5,
            isSmartModeEnabled: true
        )

        XCTAssertEqual(duringSound, 0.5, accuracy: 0.001)
        XCTAssertEqual(duringSilence, 6, accuracy: 0.001)
        XCTAssertLessThan(duringSound, duringSilence)
    }

    func testSmartModeOffIgnoresThePlanEntirely() {
        let rate = RateResolver.resolve(
            planned: 12,
            manualRate: 1.5,
            isSmartModeEnabled: false
        )

        XCTAssertEqual(rate, 1.5, accuracy: 0.001)
    }

    func testMissingPlanFallsBackToTheManualRate() {
        let rate = RateResolver.resolve(
            planned: nil,
            manualRate: 2,
            isSmartModeEnabled: true
        )

        XCTAssertEqual(rate, 2, accuracy: 0.001)
    }

    /// The time-pitch unit is undefined outside its supported range, so the
    /// combined rate has to be clamped before it reaches the graph.
    func testCombinedRateStaysWithinWhatTheGraphAccepts() {
        let range = PlaybackPlanConfig.supportedRateRange

        let tooFast = RateResolver.resolve(
            planned: 24,
            manualRate: 3,
            isSmartModeEnabled: true
        )
        let tooSlow = RateResolver.resolve(
            planned: 0.5,
            manualRate: 0.1,
            isSmartModeEnabled: true
        )

        XCTAssertEqual(tooFast, range.upperBound, accuracy: 0.001)
        XCTAssertEqual(tooSlow, range.lowerBound, accuracy: 0.001)
    }

    func testNonFiniteRateFallsBackToRealTime() {
        XCTAssertEqual(
            RateResolver.resolve(planned: .nan, manualRate: 1, isSmartModeEnabled: true),
            1
        )
    }
}
