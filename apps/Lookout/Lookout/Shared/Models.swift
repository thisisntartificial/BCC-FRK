import Foundation

enum NodeRole: String, Codable, Sendable {
    case camera
    case viewer
}

struct Advertisement: Codable, Sendable, Equatable {
    var role: NodeRole
    var displayName: String
    var proto: Int
    var batteryPercent: Int?
    var httpPort: Int
}

struct DiscoveredNode: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var endpointDescription: String
}

enum LookoutDefaults {
    static let roomNameKey = "lookout.roomName"
    static let roleKey = "lookout.role"
    static let customURLKey = "lookout.customURL"

    static var roomName: String {
        let stored = UserDefaults.standard.string(forKey: roomNameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (stored?.isEmpty == false) ? stored! : "Kitchen"
    }
}
