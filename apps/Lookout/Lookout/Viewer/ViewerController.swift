import Foundation
import Network
import UIKit

@Observable
@MainActor
final class ViewerController {
    var nodes: [DiscoveredNode] = []
    var pin = ""
    var customURL = UserDefaults.standard.string(forKey: LookoutDefaults.customURLKey) ?? ""
    var customToken = ""
    var statusLine = "Looking for cameras…"
    var lastError: String?
    var latestJPEG: Data?
    var connectedName: String?

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var reader = FrameReader()
    private var resultByID: [String: NWBrowser.Result] = [:]
    private var snapTimer: Timer?

    func startBrowsing() {
        stop()
        statusLine = "Looking for cameras…"
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: LookoutBonjour.serviceType, domain: nil), using: parameters)
        browser.browseResultsChangedHandler = { [weak self] resultSet, _ in
            Task { @MainActor in
                self?.apply(resultSet)
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                if case .failed(let error) = state {
                    self?.lastError = error.localizedDescription
                    self?.statusLine = "Browse failed — check Local Network permission"
                }
            }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func connect(to node: DiscoveredNode) {
        guard LookoutPin.isValid(pin) else {
            lastError = "Enter the 6-digit PIN from the camera phone"
            return
        }
        guard let result = resultByID[node.id] else {
            lastError = "Camera disappeared"
            return
        }
        statusLine = "Connecting to \(node.name)…"
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleState(state, name: node.name, connection: connection)
            }
        }
        connection.start(queue: .main)
        self.connection = connection
        connectedName = node.name
    }

    func connectCustomURL() {
        let trimmed = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.host != nil else {
            lastError = "Custom URL looks invalid"
            return
        }
        UserDefaults.standard.set(trimmed, forKey: LookoutDefaults.customURLKey)
        stopPeer()
        statusLine = "Polling \(trimmed)"
        connectedName = url.host
        snapTimer?.invalidate()
        snapTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollSnap(url)
            }
        }
    }

    func stop() {
        snapTimer?.invalidate()
        snapTimer = nil
        browser?.cancel()
        browser = nil
        stopPeer()
    }

    private func stopPeer() {
        connection?.cancel()
        connection = nil
        reader = FrameReader()
    }

    private func apply(_ resultSet: Set<NWBrowser.Result>) {
        var next: [DiscoveredNode] = []
        var map: [String: NWBrowser.Result] = [:]
        for result in resultSet {
            let name: String
            if case .service(let serviceName, _, _, _) = result.endpoint {
                name = serviceName
            } else {
                name = String(describing: result.endpoint)
            }
            let id = name + String(describing: result.endpoint)
            next.append(DiscoveredNode(id: id, name: name, endpointDescription: String(describing: result.endpoint)))
            map[id] = result
        }
        nodes = next.sorted { $0.name < $1.name }
        resultByID = map
        if connectedName == nil {
            statusLine = nodes.isEmpty ? "Looking for cameras…" : "\(nodes.count) camera\(nodes.count == 1 ? "" : "s") nearby"
        }
    }

    private func handleState(_ state: NWConnection.State, name: String, connection: NWConnection) {
        switch state {
        case .ready:
            lastError = nil
            statusLine = "Paired · \(name)"
            let hello = FramedMessage(type: .control, ptsMs: 0, payload: ControlHello.encode(pin: pin, token: "viewer"))
            connection.send(content: hello.encoded(), completion: .contentProcessed { [weak self] _ in
                Task { @MainActor in
                    self?.receive(from: connection)
                }
            })
        case .failed(let error):
            lastError = error.localizedDescription
            statusLine = "Connection failed"
        case .cancelled:
            if connectedName == name {
                statusLine = "Disconnected"
            }
        default:
            break
        }
    }

    private func receive(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                if let data {
                    do {
                        for message in try self.reader.push(data) {
                            if message.type == .video {
                                self.latestJPEG = message.payload
                            }
                        }
                    } catch {
                        self.lastError = "Bad frame"
                        return
                    }
                }
                if isComplete { return }
                self.receive(from: connection)
            }
        }
    }

    private func pollSnap(_ base: URL) async {
        var url = base
        if url.path.isEmpty || url.path == "/" {
            url.append(path: "snap")
        }
        var request = URLRequest(url: url)
        if customToken.isEmpty == false {
            request.setValue(customToken, forHTTPHeaderField: "X-Lookout-Token")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = "Your route is down"
                return
            }
            latestJPEG = data
            lastError = nil
            statusLine = "Custom URL · live"
        } catch {
            lastError = "Your route is down"
        }
    }
}
