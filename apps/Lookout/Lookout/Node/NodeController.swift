import Foundation
import Network
import UIKit

@Observable
@MainActor
final class NodeController {
    var roomName: String
    var pin: String
    var token: String
    var host: String
    var statusLine = "Starting…"
    var viewerCount = 0
    var lastError: String?

    private var listener: NWListener?
    private var http: NodeHTTPServer?
    private var capture: NodeCapturePipeline?
    private var sessions: [ObjectIdentifier: Session] = [:]

    var addressBlock: String {
        LANAddress.displayBlock(room: roomName, host: host)
    }

    init(roomName: String = LookoutDefaults.roomName) {
        self.roomName = roomName
        self.pin = LookoutPin.generate()
        self.token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        self.host = LANAddress.primaryHost()
    }

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        host = LANAddress.primaryHost()
        do {
            try startListener()
            let pipeline = NodeCapturePipeline()
            pipeline.onJPEG = { [weak self] data in
                Task { @MainActor in
                    self?.broadcast(jpeg: data)
                }
            }
            try pipeline.start()
            capture = pipeline
            let server = NodeHTTPServer(token: token, roomName: roomName, jpegSnapshot: { [weak pipeline] in
                pipeline?.latestJPEG
            })
            try server.start()
            http = server
            statusLine = "Wi-Fi · live"
        } catch {
            lastError = error.localizedDescription
            statusLine = "Failed to start"
        }
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        listener?.cancel()
        listener = nil
        http?.stop()
        http = nil
        capture?.stop()
        capture = nil
        sessions.values.forEach { $0.connection.cancel() }
        sessions.removeAll()
        viewerCount = 0
    }

    private func startListener() throws {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let listener = try NWListener(using: parameters)
        listener.service = NWListener.Service(
            name: roomName,
            type: LookoutBonjour.serviceType,
            txtRecord: NWTXTRecord([
                "role": "camera",
                "proto": "1",
                "name": roomName,
                "http": String(LookoutBonjour.httpPort)
            ])
        )
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed(let error) = state {
                    self?.lastError = error.localizedDescription
                    self?.statusLine = "Listener failed"
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection)
            }
        }
        listener.start(queue: .main)
        self.listener = listener
    }

    private func accept(_ connection: NWConnection) {
        let session = Session(connection: connection)
        sessions[ObjectIdentifier(connection)] = session
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed = state { self?.drop(connection) }
                if case .cancelled = state { self?.drop(connection) }
            }
        }
        connection.start(queue: .main)
        receive(on: session)
    }

    private func receive(on session: Session) {
        session.connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    self.drop(session.connection)
                    return
                }
                if let data {
                    do {
                        let messages = try session.reader.push(data)
                        for message in messages {
                            self.handle(message, session: session)
                        }
                    } catch {
                        self.drop(session.connection)
                        return
                    }
                }
                if isComplete {
                    self.drop(session.connection)
                    return
                }
                self.receive(on: session)
            }
        }
    }

    private func handle(_ message: FramedMessage, session: Session) {
        guard message.type == .control else { return }
        guard let hello = ControlHello.decode(message.payload), hello.pin == pin else {
            session.connection.cancel()
            drop(session.connection)
            return
        }
        session.paired = true
        viewerCount = sessions.values.filter(\.paired).count
        statusLine = "Streaming to \(viewerCount) viewer\(viewerCount == 1 ? "" : "s")"
        send(FramedMessage(type: .control, ptsMs: 0, payload: ControlHello.encode(pin: pin, token: token)), on: session)
    }

    private func broadcast(jpeg: Data) {
        let pts = UInt64(Date().timeIntervalSince1970 * 1000)
        let frame = FramedMessage(type: .video, ptsMs: pts, payload: jpeg)
        for session in sessions.values where session.paired {
            send(frame, on: session)
        }
    }

    private func send(_ message: FramedMessage, on session: Session) {
        session.connection.send(content: message.encoded(), completion: .contentProcessed { _ in })
    }

    private func drop(_ connection: NWConnection) {
        sessions[ObjectIdentifier(connection)] = nil
        connection.cancel()
        viewerCount = sessions.values.filter(\.paired).count
        if viewerCount == 0 {
            statusLine = "Wi-Fi · live"
        }
    }
}

private final class Session {
    let connection: NWConnection
    var reader = FrameReader()
    var paired = false

    init(connection: NWConnection) {
        self.connection = connection
    }
}
