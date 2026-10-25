import NetworkExtension
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testCoreCacheUsesTheProcessPrivateDirectory() throws {
    let cache = try SharedContainer.coreCache()
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true
    )
    XCTAssertEqual(cache.deletingLastPathComponent(), support)
    XCTAssertEqual(cache.lastPathComponent, "CoreCache")
    XCTAssertNotEqual(cache.deletingLastPathComponent(), try SharedContainer.home())
  }

  func testDefaultRoutesCaptureIPv4AndIPv6() throws {
    let settings = try TunnelSettings.make([:])
    XCTAssertEqual(settings.ipv4Settings?.includedRoutes?.map(\.destinationAddress), ["0.0.0.0"])
    XCTAssertEqual(settings.ipv6Settings?.includedRoutes?.map(\.destinationAddress), ["::"])
    XCTAssertEqual(settings.dnsSettings?.servers, [TunnelSettings.dns])
    XCTAssertEqual(settings.dnsSettings?.matchDomains, [""])
    XCTAssertEqual(settings.mtu?.intValue, 1500)
  }

  func testCustomRoutesKeepTheirPrefixLengths() throws {
    let settings = try TunnelSettings.make([
      "ipv6": true, "routeAddress": ["10.0.0.0/8", "2001:db8::/32"],
    ])
    XCTAssertEqual(settings.ipv4Settings?.includedRoutes?.first?.destinationSubnetMask, "255.0.0.0")
    XCTAssertEqual(settings.ipv6Settings?.includedRoutes?.first?.destinationNetworkPrefixLength, 32)
  }

  func testDisablingIPv6CapturesItForDropping() throws {
    let settings = try TunnelSettings.make(["ipv6": false, "routeAddress": ["0.0.0.0/0"]])
    XCTAssertEqual(settings.ipv6Settings?.includedRoutes?.map(\.destinationAddress), ["::"])
  }

  func testMalformedRoutesAreRejected() {
    for route in ["bad", "0.0.0.0/33", "invalid/24", "::/129", "::/", "::1/-1"] {
      XCTAssertThrowsError(try TunnelSettings.make(["routeAddress": [route]]), route)
    }
  }

  func testMTURespectsTheIPv6MinimumAndUpperBound() {
    XCTAssertEqual(TunnelSettings.mtu(["mtu": 0]), 1500)
    XCTAssertEqual(TunnelSettings.mtu(["mtu": 500]), 1280)
    XCTAssertEqual(TunnelSettings.mtu(["mtu": 9001]), 9000)
  }
}
