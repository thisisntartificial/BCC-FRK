import Foundation
import Network

final class NodeHTTPServer {
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
        parameters.includePeerToPeer = true
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: LookoutBonjour.httpPort)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: .global(qos: .userInitiated))
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
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

    func response(for request: String) -> Data {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let rawPath = firstLine.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let path = rawPath.split(separator: "?").first.map(String.init) ?? rawPath
        let authorized = request.contains("X-Lookout-Token: \(token)")
            || rawPath.contains("token=\(token)")

        if path == "/health" || path.hasPrefix("/health") {
            let escaped = roomName.replacingOccurrences(of: "\"", with: "")
            let body = Data("{\"room\":\"\(escaped)\",\"live\":true}".utf8)
            return http(200, contentType: "application/json", body: body)
        }

        guard authorized else {
            return http(401, contentType: "text/plain", body: Data("token required".utf8))
        }

        if path.hasPrefix("/snap"), let jpeg = jpegSnapshot() {
            return http(200, contentType: "image/jpeg", body: jpeg)
        }

        if path == "/" {
            let html = """
            <html><body style="background:#111;color:#eee;font-family:sans-serif">
            <h1>Lookout · \(roomName)</h1>
            <p>Use the Lookout app or GET /snap with X-Lookout-Token.</p>
            </body></html>
            """
            return http(200, contentType: "text/html", body: Data(html.utf8))
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
