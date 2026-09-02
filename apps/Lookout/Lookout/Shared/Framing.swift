import Foundation

enum LookoutBonjour {
    static let serviceType = "_lookout._tcp"
    static let httpPort: UInt16 = 8787
}

enum FrameType: UInt8, Sendable {
    case video = 1
    case control = 2
    case heartbeat = 3
}

enum CameraTransportError: Error, Sendable {
    case invalidFrame
    case pairingRejected
}

struct FramedMessage: Sendable, Equatable {
    var type: FrameType
    var ptsMs: UInt64
    var payload: Data

    func encoded() -> Data {
        var length = UInt32(1 + 8 + payload.count).bigEndian
        var pts = ptsMs.bigEndian
        var data = Data()
        data.append(Data(bytes: &length, count: 4))
        data.append(type.rawValue)
        data.append(Data(bytes: &pts, count: 8))
        data.append(payload)
        return data
    }

    static func decode(_ data: Data) -> FramedMessage? {
        guard data.count >= 13 else { return nil }
        let length = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard data.count == Int(length) + 4 else { return nil }
        guard let type = FrameType(rawValue: data[4]) else { return nil }
        let pts = data.subdata(in: 5 ..< 13).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        return FramedMessage(type: type, ptsMs: pts, payload: data.suffix(from: 13))
    }
}

struct FrameReader: Sendable {
    private var buffer = Data()
    private let maxFrameBytes = 1_048_576

    mutating func push(_ chunk: Data) throws -> [FramedMessage] {
        buffer.append(chunk)
        var messages: [FramedMessage] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length <= maxFrameBytes else {
                throw CameraTransportError.invalidFrame
            }
            let total = Int(length) + 4
            guard buffer.count >= total else { break }
            let slice = Data(buffer.prefix(total))
            buffer.removeFirst(total)
            guard let message = FramedMessage.decode(slice) else {
                throw CameraTransportError.invalidFrame
            }
            messages.append(message)
        }
        return messages
    }
}

enum LookoutPin {
    static func generate() -> String {
        String(format: "%06d", Int.random(in: 0 ... 999_999))
    }

    static func isValid(_ pin: String) -> Bool {
        pin.range(of: "^[0-9]{6}$", options: .regularExpression) != nil
    }
}

enum ControlHello {
    static func encode(pin: String, token: String) -> Data {
        let body = ["pin": pin, "token": token]
        return (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
    }

    static func decode(_ payload: Data) -> (pin: String, token: String)? {
        guard
            let object = try? JSONSerialization.jsonObject(with: payload) as? [String: String],
            let pin = object["pin"],
            let token = object["token"],
            LookoutPin.isValid(pin),
            token.isEmpty == false
        else {
            return nil
        }
        return (pin, token)
    }
}
