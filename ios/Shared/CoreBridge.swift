import Clash
import Foundation

enum TunnelError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self {
    case .message(let message): return message
    }
  }
}

enum SharedContainer {
  static var appGroup: String {
    Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as! String
  }

  static func home() throws -> URL {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else {
      throw TunnelError.message("The iPing App Group is unavailable. Check signing and entitlements.")
    }
    let home = container.appendingPathComponent("Library/Application Support/iPing", isDirectory: true)
    try FileManager.default.createDirectory(
      at: home, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    )
    return home
  }

  static func state() throws -> [String: Any] {
    let data = try Data(contentsOf: home().appendingPathComponent("tunnel-state.json"))
    guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw TunnelError.message("Invalid tunnel configuration")
    }
    return value
  }

  static func coreCache() throws -> URL {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true
    ).appendingPathComponent("CoreCache", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
    )
    return directory
  }

  static func json(_ value: Any) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
  }
}

final class CoreReply: NSObject, MobileResultHandlerProtocol {
  private let reply: (Data) -> Void

  init(_ reply: @escaping (Data) -> Void) {
    self.reply = reply
  }

  func onResult(_ data: Data?) throws {
    reply(data ?? Data())
  }
}

enum CoreBridge {
  static let queue = DispatchQueue(label: "my.iping.client.core", qos: .userInitiated)

  static func prepare(tunnel: Bool) throws {
    var error: NSError?
    if !MobilePrepare(try SharedContainer.home().path, try SharedContainer.coreCache().path, tunnel, &error) {
      throw error ?? TunnelError.message("The iOS Core could not initialize")
    }
  }

  static func invoke(_ request: String) async -> Data {
    await withCheckedContinuation { continuation in
      queue.async {
        MobileInvokeMethod(request, CoreReply { continuation.resume(returning: $0) })
      }
    }
  }

  static func invoke(method: String) async throws {
    let request = try SharedContainer.json(["id": UUID().uuidString, "method": method])
    let response = await invoke(request)
    let envelope = try JSONSerialization.jsonObject(with: response) as? [String: Any]
    if let error = envelope?["error"] as? [String: Any] {
      throw TunnelError.message(error["message"] as? String ?? "Core request failed")
    }
  }

  static func setup(_ state: [String: Any]) async throws {
    let home = try SharedContainer.home()
    let initial = try SharedContainer.json(["home-dir": home.path, "version": 0])
    let parameters = try SharedContainer.json(state["setupParams"] as? [String: Any] ?? [:])
    let error: String = await withCheckedContinuation { continuation in
      queue.async {
        MobileQuickSetup(initial, parameters, CoreReply {
          continuation.resume(returning: String(decoding: $0, as: UTF8.self))
        })
      }
    }
    if !error.isEmpty { throw TunnelError.message(error) }
  }
}
