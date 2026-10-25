import Darwin
import Foundation
import NetworkExtension

enum TunnelSettings {
  static let ipv4 = "198.18.0.1"
  static let ipv6 = "fdfe:dcba:9876::1"
  static let dns = "198.18.0.2"

  static func make(_ options: [String: Any]) throws -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
    settings.mtu = NSNumber(value: mtu(options))
    let routes = options["routeAddress"] as? [String] ?? []
    let v4 = NEIPv4Settings(addresses: [ipv4], subnetMasks: ["255.255.255.252"])
    let v6 = NEIPv6Settings(addresses: [ipv6], networkPrefixLengths: [64])
    var routes4 = [NEIPv4Route]()
    var routes6 = [NEIPv6Route]()
    for route in routes {
      let parts = route.split(separator: "/", omittingEmptySubsequences: false)
      guard parts.count == 2, let prefix = Int(parts[1]) else {
        throw TunnelError.message("Invalid VPN route: \(route)")
      }
      let address = String(parts[0])
      if address.contains(":") {
        var parsed = in6_addr()
        guard (0...128).contains(prefix), inet_pton(AF_INET6, address, &parsed) == 1 else {
          throw TunnelError.message("Invalid IPv6 route: \(route)")
        }
        routes6.append(NEIPv6Route(destinationAddress: address, networkPrefixLength: NSNumber(value: prefix)))
      } else {
        var parsed = in_addr()
        guard (0...32).contains(prefix), inet_pton(AF_INET, address, &parsed) == 1 else {
          throw TunnelError.message("Invalid IPv4 route: \(route)")
        }
        let mask = prefix == 0 ? UInt32(0) : UInt32.max << (32 - prefix)
        let text = [24, 16, 8, 0].map { String((mask >> $0) & 255) }.joined(separator: ".")
        routes4.append(NEIPv4Route(destinationAddress: address, subnetMask: text))
      }
    }
    v4.includedRoutes = routes.isEmpty ? [.default()] : routes4
    v6.includedRoutes = routes.isEmpty || !(options["ipv6"] as? Bool ?? false)
      ? [.default()] : routes6
    settings.ipv4Settings = v4
    settings.ipv6Settings = v6
    let resolver = NEDNSSettings(servers: [dns])
    resolver.matchDomains = [""]
    settings.dnsSettings = resolver
    return settings
  }

  static func mtu(_ options: [String: Any]) -> Int {
    let value = options["mtu"] as? Int ?? 0
    return value == 0 ? 1500 : min(9000, max(1280, value))
  }
}
