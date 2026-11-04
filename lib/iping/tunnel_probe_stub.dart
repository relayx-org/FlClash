/// The Web UI cannot open raw TCP sockets; probing stays unavailable there.
Future<int> probeListenAddress(String address, {Object? connect}) async => -1;
