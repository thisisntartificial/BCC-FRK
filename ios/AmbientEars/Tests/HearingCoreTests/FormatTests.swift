import XCTest
@testable import HearingCore

final class FormatTests: XCTestCase {
    func testDurationUnderOneMinuteShowsSecondsOnly() {
        XCTAssertEqual(Format.duration(0), "0s")
        XCTAssertEqual(Format.duration(9), "9s")
        XCTAssertEqual(Format.duration(59), "59s")
    }

    func testDurationUnderOneHourShowsMinutesAndSeconds() {
        XCTAssertEqual(Format.duration(60), "1m 00s")
        XCTAssertEqual(Format.duration(192), "3m 12s")
    }

    func testDurationOverOneHourDropsSeconds() {
        XCTAssertEqual(Format.duration(3840), "1h 04m")
        XCTAssertEqual(Format.duration(36000), "10h 00m")
    }

    func testDurationRoundsToNearestSecond() {
        XCTAssertEqual(Format.duration(9.6), "10s")
        XCTAssertEqual(Format.duration(9.4), "9s")
    }

    /// A rounding artefact should not surface as "-1s" in the interface.
    func testNegativeAndNonFiniteDurationsAreClamped() {
        XCTAssertEqual(Format.duration(-5), "0s")
        XCTAssertEqual(Format.duration(.infinity), "0s")
        XCTAssertEqual(Format.duration(.nan), "0s")
    }

    func testTimecodeAlwaysIncludesMinutes() {
        XCTAssertEqual(Format.timecode(0), "0:00")
        XCTAssertEqual(Format.timecode(7), "0:07")
        XCTAssertEqual(Format.timecode(72), "1:12")
    }

    func testTimecodeAddsHoursOnlyWhenNeeded() {
        XCTAssertEqual(Format.timecode(3599), "59:59")
        XCTAssertEqual(Format.timecode(3600), "1:00:00")
        XCTAssertEqual(Format.timecode(3723), "1:02:03")
    }

    func testTimecodePadsSecondsAndMinutes() {
        XCTAssertEqual(Format.timecode(3661), "1:01:01")
    }
}
