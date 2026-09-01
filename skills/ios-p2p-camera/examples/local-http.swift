import Foundation
import Network

/// Minimal Node HTTP bind for LAN + user-owned tunnels.
/// Video routes must check `X-Lookout-Token`. Do not advertise this port as open.
final class NodeHTTPServer {
    static let port: UInt16 = 8787

    private var listener: NWListener?
    private let token: String
    private let roomName: String
    private let jpegSnapshot: () -> Data?

    init(token: String, roomName: String, jpegSnapshot: @escaping () -> Data?) {
        self.token = token
        self.roomName = roomName
        self.jpegSnapshot = jpegSnapshot
    }

    func start() throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: Self.port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    func lanURL(host: String) -> URL? {
        URL(string: "http://\(host):\(Self.port)")
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let response = self.response(for: request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for request: String) -> Data {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let path = firstLine.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let authorized = request.contains("X-Lookout-Token: \(token)")
            || request.contains("token=\(token)")

        if path.hasPrefix("/health") {
            let body = Data(#"{"room":"\#(roomName)"}"#.utf8)
            return http(200, contentType: "application/json", body: body)
        }

        guard authorized else {
            return http(401, contentType: "text/plain", body: Data("token required".utf8))
        }

        if path.hasPrefix("/snap"), let jpeg = jpegSnapshot() {
            return http(200, contentType: "image/jpeg", body: jpeg)
        }

        return http(404, contentType: "text/plain", body: Data("not found".utf8))
    }

    private func http(_ status: Int, contentType: String, body: Data) -> Data {
        let reason = status == 200 ? "OK" : status == 401 ? "Unauthorized" : "Not Found"
        var header = "HTTP/1.1 \(status) \(reason)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}
