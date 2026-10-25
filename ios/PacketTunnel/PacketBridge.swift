import Darwin
import Foundation
import NetworkExtension

final class PacketBridge {
  private let flow: NEPacketTunnelFlow
  private let ipv6: Bool
  private let queue = DispatchQueue(label: "my.iping.client.packets", qos: .userInteractive)
  private var source: DispatchSourceRead?
  private var running = false
  private var stopped = false
  private var coreDescriptor: Int32
  private let descriptor: Int32

  init(flow: NEPacketTunnelFlow, ipv6: Bool) throws {
    self.flow = flow
    self.ipv6 = ipv6
    var descriptors: [Int32] = [-1, -1]
    guard socketpair(AF_UNIX, SOCK_DGRAM, 0, &descriptors) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    coreDescriptor = descriptors[0]
    descriptor = descriptors[1]
    _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
    for fd in descriptors {
      var size: Int32 = 1 << 20
      setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &size, socklen_t(MemoryLayout<Int32>.size))
      setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &size, socklen_t(MemoryLayout<Int32>.size))
    }
  }

  func takeCoreDescriptor() -> Int32 {
    let result = coreDescriptor
    coreDescriptor = -1
    return result
  }

  func start() {
    queue.async { [self] in
      guard !stopped else { return }
      running = true
      let reader = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
      reader.setEventHandler { [weak self] in self?.receive() }
      reader.setCancelHandler { [descriptor] in Darwin.close(descriptor) }
      source = reader
      reader.resume()
      readPackets()
    }
  }

  func stop() {
    queue.async { [self] in
      guard !stopped else { return }
      stopped = true
      running = false
      if let source {
        source.cancel()
        self.source = nil
      } else {
        Darwin.close(descriptor)
      }
    }
  }

  private func readPackets() {
    guard running else { return }
    flow.readPackets { [weak self] packets, protocols in
      guard let self else { return }
      self.queue.async {
        guard self.running else { return }
        for (packet, family) in zip(packets, protocols) {
          if family.int32Value == AF_INET6 && !self.ipv6 { continue }
          var header = UInt32(family.int32Value).bigEndian
          var framed = withUnsafeBytes(of: &header) { Data($0) }
          framed.append(packet)
          framed.withUnsafeBytes { bytes in
            _ = Darwin.send(self.descriptor, bytes.baseAddress, bytes.count, 0)
          }
        }
        self.readPackets()
      }
    }
  }

  private func receive() {
    guard running else { return }
    var buffer = [UInt8](repeating: 0, count: 65540)
    var packets = [Data]()
    var protocols = [NSNumber]()
    while packets.count < 64 {
      let count = Darwin.recv(descriptor, &buffer, buffer.count, 0)
      if count <= 0 { break }
      guard count > 4 else { continue }
      let family = buffer[3]
      guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }
      packets.append(Data(buffer[4..<count]))
      protocols.append(NSNumber(value: family))
    }
    if !packets.isEmpty { flow.writePackets(packets, withProtocols: protocols) }
  }

  deinit {
    if coreDescriptor >= 0 { Darwin.close(coreDescriptor) }
  }
}
