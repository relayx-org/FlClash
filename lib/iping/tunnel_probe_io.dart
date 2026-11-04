import 'dart:io';

const _timeout = Duration(seconds: 5);

typedef IpingConnector =
    Future<Socket> Function(String host, int port, {Duration? timeout});

/// TCP connect time in milliseconds, or -1 when the address does not answer.
Future<int> probeListenAddress(
  String address, {
  IpingConnector connect = Socket.connect,
}) async {
  final split = address.lastIndexOf(':');
  final port = int.tryParse(address.substring(split + 1));
  if (split < 1 || port == null) return -1;
  var host = address.substring(0, split);
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  final watch = Stopwatch()..start();
  try {
    final socket = await connect(host, port, timeout: _timeout);
    final elapsed = watch.elapsedMilliseconds;
    socket.destroy();
    return elapsed;
  } on Object {
    return -1;
  }
}
