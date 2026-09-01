import XCTest
@testable import AmbientEars

final class FormatTests: XCTestCase {
    func testDurationUsesHoursWhenLongEnough() {
        XCTAssertEqual(Format.duration(3_840), "1h 04m")
    }

    func testDurationUsesMinutesAndSeconds() {
        XCTAssertEqual(Format.duration(192), "3m 12s")
    }

    func testDurationUsesSecondsOnlyWhenBrief() {
        XCTAssertEqual(Format.duration(9), "9s")
    }

    func testTimecodeAlwaysIncludesMinutes() {
        XCTAssertEqual(Format.timecode(9), "0:09")
        XCTAssertEqual(Format.timecode(75), "1:15")
    }

    func testTimecodeIncludesHoursForLongRecordings() {
        XCTAssertEqual(Format.timecode(3_725), "1:02:05")
    }

    func testDestinationURLsAreUniquePerSecondAndUseWav() {
        let first = Recording.makeDestinationURL(now: Date(timeIntervalSince1970: 0))
        let second = Recording.makeDestinationURL(now: Date(timeIntervalSince1970: 61))

        XCTAssertEqual(first.pathExtension, "wav")
        XCTAssertNotEqual(first, second)
    }
}
