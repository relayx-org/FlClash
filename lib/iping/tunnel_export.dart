import 'dart:convert';

import 'tunnel.dart';

enum IpingTunnelExportFormat { lines, clash, csv }

class IpingTunnelExport {
  const IpingTunnelExport({required this.text, required this.count});

  final String text;
  final int count;
}

class _Entry {
  const _Entry({
    required this.name,
    required this.host,
    required this.port,
    required this.protocol,
    required this.username,
    required this.password,
    required this.cipher,
    required this.expiry,
  });

  final String name;
  final String host;
  final int port;
  final String? protocol;
  final String username;
  final String password;
  final String? cipher;
  final DateTime? expiry;
}

const _clashTypes = {'socks5', 'http', 'ss'};

/// A tunnel without a listen protocol relays straight to its forward address,
/// which the store always fills as SOCKS5.
List<_Entry> _entries(List<IpingTunnel> tunnels) {
  final entries = <_Entry>[];
  for (final tunnel in tunnels) {
    if (tunnel.listenPort == null) continue;
    final listen = tunnel.listenProtocol;
    final hasForwardAuth =
        (tunnel.forwardUsername ?? '').isNotEmpty ||
        (tunnel.forwardPassword ?? '').isNotEmpty;
    final protocol = listen ?? (hasForwardAuth ? 'socks5' : null);
    final isShadowsocks = listen == 'ss';
    final username = listen == null
        ? tunnel.forwardUsername ?? ''
        : tunnel.listenUsername ?? '';
    final password = listen == null
        ? tunnel.forwardPassword ?? ''
        : tunnel.listenPassword ?? '';
    final addresses = tunnel.listenAddresses;
    for (final (index, address) in addresses.indexed) {
      final split = address.lastIndexOf(':');
      final port = int.tryParse(address.substring(split + 1));
      if (split < 1 || port == null) continue;
      var host = address.substring(0, split);
      if (host.startsWith('[') && host.endsWith(']')) {
        host = host.substring(1, host.length - 1);
      }
      entries.add(
        _Entry(
          name: addresses.length == 1
              ? tunnel.name
              : '${tunnel.name} #${index + 1}',
          host: host,
          port: port,
          protocol: protocol,
          username: isShadowsocks ? '' : username,
          password: password,
          cipher: isShadowsocks ? username : null,
          expiry: tunnel.expiredAt,
        ),
      );
    }
  }
  return entries;
}

String _hostPort(String host, int port) =>
    host.contains(':') ? '[$host]:$port' : '$host:$port';

String _csvField(String value) {
  const quote = '"';
  final special =
      value.contains(quote) || value.contains(',') || value.contains('\n');
  if (!special) return value;
  return quote + value.replaceAll(quote, quote + quote) + quote;
}

String _clash(List<_Entry> entries) {
  final used = <String>{};
  final buffer = StringBuffer('proxies:\n');
  for (final entry in entries) {
    final base = entry.name.isEmpty ? entry.host : entry.name;
    var name = base;
    for (var n = 2; !used.add(name); n++) {
      name = '$base ($n)';
    }
    buffer
      ..writeln('  - name: ${jsonEncode(name)}')
      ..writeln('    type: ${entry.protocol}')
      ..writeln('    server: ${jsonEncode(entry.host)}')
      ..writeln('    port: ${entry.port}');
    if (entry.cipher case final cipher?) {
      buffer.writeln('    cipher: ${jsonEncode(cipher)}');
    } else if (entry.username.isNotEmpty) {
      buffer.writeln('    username: ${jsonEncode(entry.username)}');
    }
    if (entry.password.isNotEmpty) {
      buffer.writeln('    password: ${jsonEncode(entry.password)}');
    }
    if (entry.protocol != 'http') buffer.writeln('    udp: true');
  }
  return buffer.toString();
}

IpingTunnelExport exportTunnels(
  List<IpingTunnel> tunnels,
  IpingTunnelExportFormat format,
) {
  final all = _entries(tunnels);
  switch (format) {
    case IpingTunnelExportFormat.lines:
      return IpingTunnelExport(
        count: all.length,
        text: [
          for (final entry in all)
            [
              _hostPort(entry.host, entry.port),
              if (entry.username.isNotEmpty || entry.password.isNotEmpty) ...[
                entry.cipher ?? entry.username,
                entry.password,
              ],
            ].join(':'),
        ].join('\n'),
      );
    case IpingTunnelExportFormat.clash:
      final supported = [
        for (final entry in all)
          if (_clashTypes.contains(entry.protocol)) entry,
      ];
      return IpingTunnelExport(
        count: supported.length,
        text: supported.isEmpty ? '' : _clash(supported),
      );
    case IpingTunnelExportFormat.csv:
      return IpingTunnelExport(
        count: all.length,
        text: [
          'name,host,port,protocol,username,password,expires_at',
          for (final entry in all)
            [
              entry.name,
              entry.host,
              '${entry.port}',
              entry.protocol ?? '',
              entry.cipher ?? entry.username,
              entry.password,
              entry.expiry?.toUtc().toIso8601String() ?? '',
            ].map(_csvField).join(','),
        ].join('\n'),
      );
  }
}
