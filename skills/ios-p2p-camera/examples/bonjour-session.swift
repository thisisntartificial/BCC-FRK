import Foundation
import Network

/// Bonjour service type. Must match Info.plist NSBonjourServices.
enum LookoutBonjour {
    static let serviceType = "_lookout._tcp"
}

// MARK: - Framing

enum FrameType: UInt8 {
    case video = 1
    case control = 2
    case heartbeat = 3
}

struct FramedMessage: Sendable {
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
        let pts = data.subdata(in: 5..<13).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        return FramedMessage(type: type, ptsMs: pts, payload: data.suffix(from: 13))
    }
}

/// Incremental unframer for TCP. Cap frames so a hostile peer cannot OOM the Viewer.
actor FrameReader {
    private var buffer = Data()
    private let maxFrameBytes = 1_048_576

    func push(_ chunk: Data) throws -> [FramedMessage] {
        buffer.append(chunk)
        var messages: [FramedMessage] = []
        while buffer.count >= 4 {
            let length = buffer.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length <= maxFrameBytes else {
                throw CameraTransportError.invalidFrame
            }
            let total = Int(length) + 4
            guard buffer.count >= total else { break }
            let slice = buffer.prefix(total)
            buffer.removeFirst(total)
            guard let message = FramedMessage.decode(Data(slice)) else {
                throw CameraTransportError.invalidFrame
            }
            messages.append(message)
        }
        return messages
    }
}

enum CameraTransportError: Error {
    case invalidFrame
    case pairingRejected
}

// MARK: - Camera Node listener

final class CameraListener {
    private var listener: NWListener?
    private let pin: String
    private let onSession: (NWConnection) -> Void

    init(pin: String, onSession: @escaping (NWConnection) -> Void) {
        self.pin = pin
        self.onSession = onSession
    }

    func start(displayName: String) throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(
            name: displayName,
            type: LookoutBonjour.serviceType,
            txtRecord: NWTXTRecord(["role": "camera", "proto": "1", "name": displayName])
        )
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        // First control message must be {"pin":"123456"} before video flows.
        receivePin(on: connection)
    }

    private func receivePin(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 13, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }
            guard let message = FramedMessage.decode(data),
                  message.type == .control,
                  let body = try? JSONSerialization.jsonObject(with: message.payload) as? [String: String],
                  body["pin"] == self.pin
            else {
                connection.cancel()
                return
            }
            self.onSession(connection)
        }
    }
}

// MARK: - Viewer browser

final class CameraBrowser: ObservableObject {
    @Published private(set) var results: [NWBrowser.Result] = []
    private var browser: NWBrowser?

    func start() {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: LookoutBonjour.serviceType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] resultSet, _ in
            self?.results = Array(resultSet)
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func connect(to result: NWBrowser.Result, pin: String, onReady: @escaping (NWConnection) -> Void) {
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            guard case .ready = state else { return }
            let payload = try? JSONSerialization.data(withJSONObject: ["pin": pin])
            let hello = FramedMessage(type: .control, ptsMs: 0, payload: payload ?? Data()).encoded()
            connection.send(content: hello, completion: .contentProcessed { _ in
                onReady(connection)
            })
        }
        connection.start(queue: .main)
    }
}
