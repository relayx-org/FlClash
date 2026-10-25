import Clash
import Flutter
import NetworkExtension
import UIKit

@MainActor
final class IOSService: NSObject {
  private let service: FlutterMethodChannel
  private let core: FlutterMethodChannel
  private var manager: NETunnelProviderManager?
  private var observers = [NSObjectProtocol]()
  private var poll: Task<Void, Never>?
  private var worker: Task<Void, Never>?
  private var waiters = [CheckedContinuation<Bool, Error>]()
  private var readers = [CheckedContinuation<Void, Never>]()
  private var intent = 0
  private var command = 0
  private var desiredRunning = false
  private var attached = false
  private var observedRunning = false
  private var localReady = false
  private var localEvents: CoreReply?

  init(messenger: FlutterBinaryMessenger) {
    service = FlutterMethodChannel(name: "my.iping.client/service", binaryMessenger: messenger)
    core = FlutterMethodChannel(name: "my.iping.client/core", binaryMessenger: messenger)
    super.init()
    service.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else { return }
        do {
          result(try await self.handle(call))
        } catch {
          result(FlutterError(code: "ios_service", message: error.localizedDescription, details: nil))
        }
      }
    }
    core.setMethodCallHandler { [weak self] call, result in
      Task { @MainActor in
        guard let self else { return }
        guard call.method == "invokeMethod", let request = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        do {
          while self.worker != nil {
            await withCheckedContinuation { self.readers.append($0) }
          }
          let data = try await self.invoke(request)
          result(FlutterStandardTypedData(bytes: data))
        } catch {
          result(FlutterError(code: "ios_core", message: error.localizedDescription, details: nil))
        }
      }
    }
    for name in [Notification.Name.NEVPNStatusDidChange, UIApplication.willEnterForegroundNotification] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] _ in Task { @MainActor in await self?.statusChanged() }
      })
    }
    observers.append(NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in self?.stopPolling() }
    })
  }

  private var extensionIdentifier: String {
    "\(Bundle.main.bundleIdentifier!).PacketTunnel"
  }

  private var connected: Bool {
    manager?.connection.status == .connected || manager?.connection.status == .reasserting
  }

  private func handle(_ call: FlutterMethodCall) async throws -> Any? {
    switch call.method {
    case "homeDirectory": return try SharedContainer.home().path
    case "init":
      try CoreBridge.prepare(tunnel: false)
      attached = true
      localEvents = CoreReply { [weak self] data in
        Task { @MainActor in
          guard let self, self.attached, !self.connected else { return }
          self.service.invokeMethod("event", arguments: FlutterStandardTypedData(bytes: data))
        }
      }
      MobileSetEventListener(localEvents)
      manager = try await loadManager(create: false)
      observedRunning = connected
      startPolling()
      return ""
    case "syncState":
      guard let json = call.arguments as? String, let data = json.data(using: .utf8),
        let state = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        state["setupParams"] is [String: Any], state["vpnOptions"] is [String: Any]
      else { throw TunnelError.message("Invalid shared VPN state") }
      try data.write(to: SharedContainer.home().appendingPathComponent("tunnel-state.json"), options: .atomic)
      return ""
    case "start", "stop":
      command = call.arguments as? Int ?? command
      desiredRunning = call.method == "start"
      intent += 1
      return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
        waiters.append(continuation)
        if worker == nil {
          worker = Task { @MainActor in await self.reconcile() }
        }
      }
    case "getRunTime":
      guard connected, let date = manager?.connection.connectedDate else { return 0 }
      return Int64(date.timeIntervalSince1970 * 1000)
    case "shutdown":
      attached = false
      stopPolling()
      MobileSetEventListener(nil)
      return true
    default: return FlutterMethodNotImplemented
    }
  }

  private func reconcile() async {
    var error: Error?
    var consumed = -1
    while consumed != intent {
      let current = intent
      error = nil
      let target = desiredRunning
      do {
        if target { try await start(current) } else { try await stop() }
      } catch let failure {
        if current == intent {
          error = failure
          desiredRunning = false
          manager?.connection.stopVPNTunnel()
          try? await waitForStatus(running: false, current: current)
          try? await restoreLocal()
        }
      }
      consumed = current
    }
    worker = nil
    let pending = waiters
    waiters.removeAll()
    let pendingReaders = readers
    readers.removeAll()
    for reader in pendingReaders { reader.resume() }
    for waiter in pending {
      if let error { waiter.resume(throwing: error) } else { waiter.resume(returning: true) }
    }
    startPolling()
  }

  private func start(_ current: Int) async throws {
    if connected { return }
    manager = try await loadManager(create: true)
    guard current == intent, desiredRunning, let manager else { return }
    if manager.connection.status == .disconnecting {
      try await waitForStatus(running: false, current: current)
    }
    guard current == intent, desiredRunning else { return }
    if manager.connection.status == .connecting {
      try await waitForStatus(running: true, current: current)
    }
    guard current == intent, desiredRunning else { return }
    if connected {
      observedRunning = true
      return
    }
    let state = try SharedContainer.state()
    guard FileManager.default.fileExists(atPath: try SharedContainer.home().appendingPathComponent("config.yaml").path),
      state["vpnOptions"] is [String: Any]
    else { throw TunnelError.message("Apply a profile before starting the VPN") }
    try await CoreBridge.invoke(method: "shutdown")
    localReady = false
    guard current == intent, desiredRunning else { return }
    try (manager.connection as! NETunnelProviderSession).startTunnel(options: nil)
    try await waitForStatus(running: true, current: current)
    if current == intent && connected { observedRunning = true }
  }

  private func stop() async throws {
    stopPolling()
    manager?.connection.stopVPNTunnel()
    try await waitForStatus(running: false, current: intent)
    try await restoreLocal()
    observedRunning = false
  }

  private func restoreLocal() async throws {
    guard !localReady, !connected else { return }
    if let status = manager?.connection.status, status != .disconnected && status != .invalid {
      throw TunnelError.message("The VPN has not finished disconnecting")
    }
    if FileManager.default.fileExists(atPath: try SharedContainer.home().appendingPathComponent("config.yaml").path) {
      try await CoreBridge.setup(SharedContainer.state())
    }
    localReady = true
    if attached { MobileSetEventListener(localEvents) }
  }

  private func waitForStatus(running: Bool, current: Int) async throws {
    var beganConnecting = false
    for _ in 0..<200 {
      guard current == intent else { return }
      let status = manager?.connection.status ?? .disconnected
      if status == .connecting || status == .reasserting { beganConnecting = true }
      if running && status == .connected { return }
      if !running && (status == .disconnected || status == .invalid) { return }
      if running && beganConnecting && (status == .disconnected || status == .invalid) {
        throw TunnelError.message("The VPN extension stopped before connecting. Check its device log and signing.")
      }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    throw TunnelError.message("The VPN transition timed out")
  }

  private func loadManager(create: Bool) async throws -> NETunnelProviderManager? {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    if let existing = managers.first(where: {
      ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionIdentifier
    }) {
      if create && !existing.isEnabled {
        existing.isEnabled = true
        try await existing.saveToPreferences()
        try await existing.loadFromPreferences()
      }
      return existing
    }
    guard create else { return nil }
    let result = NETunnelProviderManager()
    let configuration = NETunnelProviderProtocol()
    configuration.providerBundleIdentifier = extensionIdentifier
    configuration.serverAddress = "iPing"
    configuration.disconnectOnSleep = false
    result.protocolConfiguration = configuration
    result.localizedDescription = "iPing"
    result.isEnabled = true
    try await result.saveToPreferences()
    try await result.loadFromPreferences()
    return result
  }

  private func invoke(_ request: String) async throws -> Data {
    guard connected else {
      if let status = manager?.connection.status, status != .disconnected && status != .invalid {
        throw TunnelError.message("The VPN is changing state")
      }
      let response = await CoreBridge.invoke(request)
      localReady = true
      return response
    }
    return try await send(Data(request.utf8))
  }

  private func send(_ data: Data, timeout: TimeInterval = 180) async throws -> Data {
    guard let session = manager?.connection as? NETunnelProviderSession else {
      throw TunnelError.message("The VPN session is unavailable")
    }
    return try await withCheckedThrowingContinuation { continuation in
      var completed = false
      var timer: DispatchSourceTimer?
      let finish: (Result<Data, Error>) -> Void = { result in
        guard !completed else { return }
        completed = true
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        continuation.resume(with: result)
      }
      timer = DispatchSource.makeTimerSource(queue: .main)
      timer?.schedule(deadline: .now() + timeout)
      timer?.setEventHandler {
        finish(.failure(TunnelError.message("The VPN extension did not answer")))
      }
      timer?.resume()
      do {
        try session.sendProviderMessage(data) { response in
          DispatchQueue.main.async {
            if let response { finish(.success(response)) }
            else { finish(.failure(TunnelError.message("The VPN extension disconnected"))) }
          }
        }
      } catch { finish(.failure(error)) }
    }
  }

  private func statusChanged() async {
    guard worker == nil else { return }
    if connected {
      observedRunning = true
      startPolling()
    } else if observedRunning &&
      (manager?.connection.status == .disconnected || manager?.connection.status == .invalid) {
      observedRunning = false
      stopPolling()
      try? await restoreLocal()
      if attached { service.invokeMethod("stopped", arguments: command) }
    }
  }

  private func startPolling() {
    guard poll == nil, attached, connected, UIApplication.shared.applicationState != .background else { return }
    poll = Task { @MainActor in
      while !Task.isCancelled && self.attached && self.connected {
        do {
          let response = try await self.send(Data("events".utf8), timeout: 2)
          let batch = try JSONSerialization.jsonObject(with: response) as? [String] ?? []
          for event in batch {
            if let data = Data(base64Encoded: event) {
              self.service.invokeMethod("event", arguments: FlutterStandardTypedData(bytes: data))
            }
          }
          try await Task.sleep(nanoseconds: 100_000_000)
        } catch { break }
      }
      self.poll = nil
    }
  }

  private func stopPolling() {
    poll?.cancel()
    poll = nil
  }

  deinit {
    poll?.cancel()
    worker?.cancel()
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }
}
