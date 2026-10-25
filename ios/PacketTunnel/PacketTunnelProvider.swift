import Clash
import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private var bridge: PacketBridge?
  private let eventLock = NSLock()
  private var events = [Data]()
  private var stateEvents = [Data]()
  private var eventBytes = 0
  private var stateBytes = 0
  private var eventDeadline = Date.distantPast
  private var listening = false
  private var generation = 0
  private var transition: Task<Void, Never>?
  private lazy var receiver = CoreReply { [weak self] in self?.enqueue($0) }

  override func startTunnel(
    options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void
  ) {
    DispatchQueue.main.async { self.start(completionHandler) }
  }

  private func start(_ completionHandler: @escaping (Error?) -> Void) {
    generation += 1
    let token = generation
    let previous = transition
    transition = Task { @MainActor [self] in
      await previous?.value
      do {
        guard token == generation else { throw CancellationError() }
        let state = try SharedContainer.state()
        guard let vpn = state["vpnOptions"] as? [String: Any] else {
          throw TunnelError.message("VPN configuration is missing")
        }
        try CoreBridge.prepare(tunnel: true)
        try await CoreBridge.setup(state)
        guard token == generation else { throw CancellationError() }
        let settings = try TunnelSettings.make(vpn)
        try await setTunnelNetworkSettings(settings)
        guard token == generation else { throw CancellationError() }
        let packetBridge = try PacketBridge(flow: packetFlow, ipv6: vpn["ipv6"] as? Bool ?? false)
        let tunOptions = try SharedContainer.json([
          "mtu": TunnelSettings.mtu(vpn),
          "congestion-controller": vpn["congestionController"] as? String ?? "",
        ])
        let descriptor = packetBridge.takeCoreDescriptor()
        let stack = vpn["stack"] as? String ?? "gvisor"
        let started: Bool = await withCheckedContinuation { continuation in
          CoreBridge.queue.async {
            continuation.resume(returning: MobileStartTun(
              descriptor, nil, stack, "\(TunnelSettings.ipv4)/30,\(TunnelSettings.ipv6)/64",
              TunnelSettings.dns, tunOptions
            ))
          }
        }
        guard started else {
          packetBridge.stop()
          throw TunnelError.message("The iOS packet tunnel could not start")
        }
        bridge = packetBridge
        guard token == generation else { throw CancellationError() }
        packetBridge.start()
        completionHandler(nil)
      } catch {
        if token == generation { await cleanup() }
        completionHandler(error)
      }
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    DispatchQueue.main.async { [self] in
      generation += 1
      let previous = transition
      transition = Task { @MainActor in
        await previous?.value
        await self.cleanup()
        completionHandler()
      }
    }
  }

  private func cleanup() async {
    bridge?.stop()
    bridge = nil
    MobileSetEventListener(nil)
    await withCheckedContinuation { continuation in
      CoreBridge.queue.async {
        MobileStopTun()
        continuation.resume()
      }
    }
    try? await CoreBridge.invoke(method: "shutdown")
    clearEvents()
  }

  private func clearEvents() {
    eventLock.lock()
    events.removeAll()
    stateEvents.removeAll()
    eventBytes = 0
    stateBytes = 0
    eventDeadline = .distantPast
    listening = false
    eventLock.unlock()
  }

  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    guard let completionHandler else { return }
    if messageData == Data("events".utf8) {
      eventLock.lock()
      eventDeadline = Date().addingTimeInterval(2)
      let activate = !listening
      listening = true
      let batch = stateEvents + events
      events.removeAll(keepingCapacity: true)
      stateEvents.removeAll(keepingCapacity: true)
      eventBytes = 0
      stateBytes = 0
      eventLock.unlock()
      if activate {
        CoreBridge.queue.async { [self] in MobileSetEventListener(receiver) }
      }
      CoreBridge.queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.expireEvents() }
      completionHandler(try? JSONSerialization.data(withJSONObject: batch.map { $0.base64EncodedString() }))
      return
    }
    Task {
      let result = await CoreBridge.invoke(String(decoding: messageData, as: UTF8.self))
      completionHandler(result)
    }
  }

  private func enqueue(_ data: Data) {
    eventLock.lock()
    defer { eventLock.unlock() }
    guard eventDeadline > Date(), data.count <= 256 * 1024 else { return }
    guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let messages = envelope["arguments"] as? [[String: Any]] else { return }
    let states = messages.filter { ["loaded", "geoUpdate", "routeChanged"].contains($0["type"] as? String ?? "") }
    let other = messages.filter { !["loaded", "geoUpdate", "routeChanged"].contains($0["type"] as? String ?? "") }
    if !states.isEmpty, let frame = try? JSONSerialization.data(withJSONObject: ["method": "message", "arguments": states]),
      stateEvents.count < 64, stateBytes + frame.count <= 256 * 1024 {
      stateEvents.append(frame)
      stateBytes += frame.count
    }
    guard !other.isEmpty,
      let frame = try? JSONSerialization.data(withJSONObject: ["method": "message", "arguments": other])
    else { return }
    while !events.isEmpty && (events.count >= 64 || eventBytes + frame.count > 256 * 1024) {
      eventBytes -= events.removeFirst().count
    }
    events.append(frame)
    eventBytes += frame.count
  }

  private func expireEvents() {
    eventLock.lock()
    let expired = eventDeadline <= Date() && listening
    if expired { listening = false }
    eventLock.unlock()
    if expired { MobileSetEventListener(nil) }
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    MobileForceGC()
    completionHandler()
  }

  override func wake() {
    MobileResetNetwork()
  }
}
