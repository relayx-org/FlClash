import 'package:fl_clash/common/input_limits.dart';
import 'package:fl_clash/enum/proxy_field.dart';
import 'package:fl_clash/l10n/l10n.dart';

extension ProxyFieldPresentation on ProxyField {
  String label(AppLocalizations l) => switch (this) {
    ProxyField.username => l.username,
    ProxyField.password => l.password,
    ProxyField.uuid => 'UUID',
    ProxyField.psk || ProxyField.preSharedKey => l.preSharedKey,
    ProxyField.authStr => l.password,
    ProxyField.key => l.secretKey,
    ProxyField.privateKey => l.privateKey,
    ProxyField.publicKey => l.publicKey,
    ProxyField.privateKeyPassphrase => l.privateKeyPassphrase,
    ProxyField.cipher => l.cipher,
    ProxyField.alterId => 'Alter ID',
    ProxyField.protocol => l.protocol,
    ProxyField.obfs => l.obfs,
    ProxyField.transport => l.transport,
    ProxyField.network => l.network,
    ProxyField.up => l.uploadBandwidth,
    ProxyField.down => l.downloadBandwidth,
    ProxyField.flow => 'Flow',
    ProxyField.wsPath => 'WebSocket Path',
    ProxyField.wsHost => 'WebSocket Host',
    ProxyField.grpcServiceName => 'gRPC Service Name',
    ProxyField.xhttpPath => 'XHTTP Path',
    ProxyField.xhttpHost => 'XHTTP Host',
    ProxyField.tls => 'TLS',
    ProxyField.sni || ProxyField.servername => 'SNI',
    ProxyField.alpn => 'ALPN',
    ProxyField.skipCertVerify => l.skipCertVerify,
    ProxyField.clientFingerprint => l.clientFingerprint,
    ProxyField.realityPublicKey => 'Reality Public Key',
    ProxyField.realityShortId => 'Reality Short ID',
    ProxyField.plugin => l.plugin,
    ProxyField.pluginMode => l.pluginMode,
    ProxyField.pluginHost => l.pluginHost,
    ProxyField.udpOverTcp => 'UDP over TCP',
    ProxyField.protocolParam => l.protocolParam,
    ProxyField.obfsParam => l.obfsParam,
    ProxyField.obfsPassword || ProxyField.obfsSecret => l.obfsPassword,
    ProxyField.obfsMode => l.obfsMode,
    ProxyField.obfsHost => l.obfsHost,
    ProxyField.version => l.protocolVersion,
    ProxyField.ports => l.portHopping,
    ProxyField.hopInterval => l.hopInterval,
    ProxyField.congestionController => l.congestionControl,
    ProxyField.udpRelayMode => l.udpRelayMode,
    ProxyField.reduceRtt => '0-RTT',
    ProxyField.ip => 'IPv4',
    ProxyField.ipv6 => 'IPv6',
    ProxyField.allowedIps => l.allowedIps,
    ProxyField.dns => 'DNS',
    ProxyField.remoteDnsResolve => l.remoteDnsResolve,
    ProxyField.mtu => 'MTU',
    ProxyField.tfo => 'TCP Fast Open',
    ProxyField.mptcp => 'MPTCP',
    ProxyField.interfaceName => l.interfaceName,
    ProxyField.routingMark => l.routingMark,
    ProxyField.ipVersion => l.ipVersion,
  };

  bool get isCredential => switch (this) {
    ProxyField.username ||
    ProxyField.password ||
    ProxyField.uuid ||
    ProxyField.psk ||
    ProxyField.key ||
    ProxyField.privateKey ||
    ProxyField.publicKey ||
    ProxyField.privateKeyPassphrase ||
    ProxyField.preSharedKey ||
    ProxyField.authStr => true,
    _ => false,
  };

  ProxyOptionSection get section => switch (this) {
    _ when isCredential => ProxyOptionSection.authentication,
    ProxyField.network ||
    ProxyField.flow ||
    ProxyField.wsPath ||
    ProxyField.wsHost ||
    ProxyField.grpcServiceName ||
    ProxyField.xhttpPath ||
    ProxyField.xhttpHost => ProxyOptionSection.transport,
    ProxyField.tls ||
    ProxyField.sni ||
    ProxyField.servername ||
    ProxyField.alpn ||
    ProxyField.skipCertVerify ||
    ProxyField.clientFingerprint ||
    ProxyField.realityPublicKey ||
    ProxyField.realityShortId => ProxyOptionSection.tls,
    ProxyField.tfo ||
    ProxyField.mptcp ||
    ProxyField.interfaceName ||
    ProxyField.routingMark ||
    ProxyField.ipVersion => ProxyOptionSection.connection,
    _ => ProxyOptionSection.other,
  };

  int get maxLength => switch (this) {
    ProxyField.username => TextInputLimits.userName,
    ProxyField.interfaceName || ProxyField.alpn => TextInputLimits.name,
    ProxyField.ip ||
    ProxyField.ipv6 ||
    ProxyField.allowedIps => TextInputLimits.cidr,
    ProxyField.dns => TextInputLimits.dnsServer,
    ProxyField.wsPath || ProxyField.xhttpPath => TextInputLimits.url,
    _ when kind == ProxyFieldKind.number => TextInputLimits.number,
    _ => TextInputLimits.domain,
  };

  String? get hintText => switch (this) {
    ProxyField.up || ProxyField.down => '100 Mbps',
    ProxyField.ports => '443,8000-9000',
    _ => null,
  };
}

enum ProxyOptionSection {
  authentication,
  transport,
  tls,
  other,
  connection;

  String label(AppLocalizations l) => switch (this) {
    authentication => l.authentication,
    transport => l.transport,
    tls => 'TLS',
    other => l.other,
    connection => l.connection,
  };
}
