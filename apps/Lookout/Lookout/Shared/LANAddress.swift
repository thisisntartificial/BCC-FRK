import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum LANAddress {
    /// IPv4 addresses on Wi-Fi / ethernet, preferring RFC1918.
    static func listed() -> [String] {
        #if canImport(Darwin)
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name.hasPrefix("lo") == false {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)
                    if ip.hasPrefix("127.") == false {
                        addresses.append(ip)
                    }
                }
            }
            pointer = interface.ifa_next
        }

        let privateNets = addresses.filter { ip in
            ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.")
        }
        return privateNets.isEmpty ? addresses : privateNets
        #else
        return []
        #endif
    }

    static func primaryHost() -> String {
        listed().first ?? "0.0.0.0"
    }

    static func displayBlock(room: String, host: String, port: UInt16 = LookoutBonjour.httpPort) -> String {
        """
        LOOKOUT · \(room.uppercased())
        \(host):\(port)
        Wi-Fi · live
        """
    }
}
