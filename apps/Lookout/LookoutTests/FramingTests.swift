import XCTest
@testable import Lookout

final class FramingTests: XCTestCase {
    func testControlHelloRoundTrip() throws {
        let payload = ControlHello.encode(pin: "482193", token: String(repeating: "ab", count: 16))
        let bytes = FramedMessage(type: .control, ptsMs: 0, payload: payload).encoded()
        let message = try XCTUnwrap(FramedMessage.decode(bytes))
        XCTAssertEqual(message.type, .control)
        let hello = try XCTUnwrap(ControlHello.decode(message.payload))
        XCTAssertEqual(hello.pin, "482193")
        XCTAssertEqual(hello.token.count, 32)
    }

    func testLengthPrefix() {
        let bytes = FramedMessage(type: .heartbeat, ptsMs: 1000, payload: Data("hi".utf8)).encoded()
        let length = bytes.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        XCTAssertEqual(Int(length), 1 + 8 + 2)
        XCTAssertEqual(bytes.count, 4 + Int(length))
        XCTAssertEqual(bytes[4], FrameType.heartbeat.rawValue)
    }

    func testDecodeRejectsTruncated() {
        XCTAssertNil(FramedMessage.decode(Data([0, 0, 0, 3, 1])))
    }

    func testReaderReassemblesChunks() throws {
        let first = FramedMessage(type: .heartbeat, ptsMs: 1, payload: Data("a".utf8)).encoded()
        let second = FramedMessage(type: .heartbeat, ptsMs: 2, payload: Data("b".utf8)).encoded()
        var stream = first
        stream.append(second)
        var reader = FrameReader()
        let mid = stream.count / 2
        let part1 = try reader.push(Data(stream.prefix(mid)))
        let part2 = try reader.push(Data(stream.suffix(from: mid)))
        let messages = part1 + part2
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(String(data: messages[0].payload, encoding: .utf8), "a")
        XCTAssertEqual(String(data: messages[1].payload, encoding: .utf8), "b")
    }

    func testReaderRejectsOversizedFrame() {
        var reader = FrameReader()
        var header = Data(count: 4)
        var huge = UInt32(2_000_000).bigEndian
        header.replaceSubrange(0..<4, with: Data(bytes: &huge, count: 4))
        XCTAssertThrowsError(try reader.push(header))
    }

    func testPinValidation() {
        XCTAssertTrue(LookoutPin.isValid(LookoutPin.generate()))
        XCTAssertFalse(LookoutPin.isValid("12345"))
        XCTAssertFalse(LookoutPin.isValid("12345a"))
        XCTAssertFalse(LookoutPin.isValid(""))
    }

    func testAddressBlock() {
        let block = LANAddress.displayBlock(room: "Kitchen", host: "192.168.1.42")
        XCTAssertTrue(block.contains("LOOKOUT · KITCHEN"))
        XCTAssertTrue(block.contains("192.168.1.42:8787"))
        XCTAssertTrue(block.contains("Wi-Fi · live"))
    }

    func testHealthDoesNotRequireToken() {
        let server = NodeHTTPServer(token: "secret", roomName: "Kitchen", jpegSnapshot: { nil })
        let data = server.response(for: "GET /health HTTP/1.1\r\n\r\n")
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("200"))
        XCTAssertTrue(text.contains("Kitchen"))
    }

    func testSnapRequiresToken() {
        let server = NodeHTTPServer(token: "secret", roomName: "Kitchen", jpegSnapshot: { Data([1, 2, 3]) })
        let denied = String(data: server.response(for: "GET /snap HTTP/1.1\r\n\r\n"), encoding: .utf8) ?? ""
        XCTAssertTrue(denied.contains("401"))
        let allowed = String(
            data: server.response(for: "GET /snap HTTP/1.1\r\nX-Lookout-Token: secret\r\n\r\n"),
            encoding: .utf8
        ) ?? ""
        XCTAssertTrue(allowed.contains("200"))
    }
}
