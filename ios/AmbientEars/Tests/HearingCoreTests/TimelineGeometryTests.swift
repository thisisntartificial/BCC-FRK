import XCTest
@testable import HearingCore

final class TimelineGeometryTests: XCTestCase {
    func testFractionMapsTimeAcrossTheStrip() {
        XCTAssertEqual(TimelineGeometry.fraction(of: 0, duration: 60), 0, accuracy: 0.001)
        XCTAssertEqual(TimelineGeometry.fraction(of: 30, duration: 60), 0.5, accuracy: 0.001)
        XCTAssertEqual(TimelineGeometry.fraction(of: 60, duration: 60), 1, accuracy: 0.001)
    }

    /// An empty recording must not divide by zero.
    func testEmptyRecordingCollapsesToTheStart() {
        XCTAssertEqual(TimelineGeometry.fraction(of: 10, duration: 0), 0)
        XCTAssertEqual(TimelineGeometry.time(atFraction: 0.5, duration: 0), 0)
    }

    func testTimesOutsideTheRecordingClampToTheEnds() {
        XCTAssertEqual(TimelineGeometry.fraction(of: -5, duration: 60), 0)
        XCTAssertEqual(TimelineGeometry.fraction(of: 120, duration: 60), 1)
    }

    /// A drag that ends past the edge of the strip should land on the nearest
    /// end rather than seeking off the recording.
    func testScrubsPastTheEdgesResolveToTheNearestEnd() {
        XCTAssertEqual(TimelineGeometry.time(atFraction: -0.2, duration: 60), 0)
        XCTAssertEqual(TimelineGeometry.time(atFraction: 1.4, duration: 60), 60)
    }

    func testScrubMapsBackToTime() {
        XCTAssertEqual(
            TimelineGeometry.time(atFraction: 0.25, duration: 120),
            30,
            accuracy: 0.001
        )
    }

    func testFractionAndTimeAreInverses() {
        let duration: TimeInterval = 187.5

        for time in stride(from: 0.0, through: duration, by: 12.5) {
            let roundTrip = TimelineGeometry.time(
                atFraction: TimelineGeometry.fraction(of: time, duration: duration),
                duration: duration
            )
            XCTAssertEqual(roundTrip, time, accuracy: 0.001)
        }
    }

    func testNonFiniteInputsCollapseToTheStart() {
        XCTAssertEqual(TimelineGeometry.fraction(of: .nan, duration: 60), 0)
        XCTAssertEqual(TimelineGeometry.time(atFraction: .nan, duration: 60), 0)
    }
}
