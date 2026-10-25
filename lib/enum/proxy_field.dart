import 'package:json_annotation/json_annotation.dart';

enum IpVersion {
  dual('dual'),
  ipv4('ipv4'),
  ipv6('ipv6'),
  @JsonValue('ipv4-prefer')
  ipv4Prefer('ipv4-prefer'),
  @JsonValue('ipv6-prefer')
  ipv6Prefer('ipv6-prefer');

  final String value;

  const IpVersion(this.value);
}

enum ProxyFieldKind { text, secret, number, toggle, choice, list }

/// A key of a proxy definition the form edits, at [path] since the core reads
/// transport, TLS and plugin settings from maps of their own.
enum ProxyField {
  username(['username']),
  password(['password'], ProxyFieldKind.secret),
  uuid(['uuid']),
  psk(['psk'], ProxyFieldKind.secret),
  key(['key'], ProxyFieldKind.secret),
  privateKey(['private-key'], ProxyFieldKind.secret),
  publicKey(['public-key']),
  privateKeyPassphrase(['private-key-passphrase'], ProxyFieldKind.secret),
  preSharedKey(['pre-shared-key'], ProxyFieldKind.secret),
  authStr(['auth-str'], ProxyFieldKind.secret),
  cipher(['cipher'], ProxyFieldKind.choice),
  alterId(['alterId'], ProxyFieldKind.number),
  protocol(['protocol'], ProxyFieldKind.choice),
  obfs(['obfs'], ProxyFieldKind.choice),
  transport(['transport'], ProxyFieldKind.choice),
  up(['up']),
  down(['down']),
  network(['network'], ProxyFieldKind.choice),
  flow(['flow'], ProxyFieldKind.choice),
  wsPath(['ws-opts', 'path']),
  wsHost(['ws-opts', 'headers', 'Host']),
  grpcServiceName(['grpc-opts', 'grpc-service-name']),
  xhttpPath(['xhttp-opts', 'path']),
  xhttpHost(['xhttp-opts', 'host']),
  tls(['tls'], ProxyFieldKind.toggle),
  sni(['sni']),
  servername(['servername']),
  alpn(['alpn'], ProxyFieldKind.list),
  skipCertVerify(['skip-cert-verify'], ProxyFieldKind.toggle),
  clientFingerprint(['client-fingerprint'], ProxyFieldKind.choice),
  realityPublicKey(['reality-opts', 'public-key']),
  realityShortId(['reality-opts', 'short-id']),
  plugin(['plugin'], ProxyFieldKind.choice),
  pluginMode(['plugin-opts', 'mode']),
  pluginHost(['plugin-opts', 'host']),
  udpOverTcp(['udp-over-tcp'], ProxyFieldKind.toggle),
  protocolParam(['protocol-param']),
  obfsParam(['obfs-param']),
  obfsPassword(['obfs-password'], ProxyFieldKind.secret),
  obfsSecret(['obfs'], ProxyFieldKind.secret),
  obfsMode(['obfs-opts', 'mode'], ProxyFieldKind.choice),
  obfsHost(['obfs-opts', 'host']),
  version(['version'], ProxyFieldKind.number),
  ports(['ports']),
  hopInterval(['hop-interval']),
  congestionController(['congestion-controller'], ProxyFieldKind.choice),
  udpRelayMode(['udp-relay-mode'], ProxyFieldKind.choice),
  reduceRtt(['reduce-rtt'], ProxyFieldKind.toggle),
  ip(['ip']),
  ipv6(['ipv6']),
  allowedIps(['allowed-ips'], ProxyFieldKind.list),
  dns(['dns'], ProxyFieldKind.list),
  remoteDnsResolve(['remote-dns-resolve'], ProxyFieldKind.toggle),
  mtu(['mtu'], ProxyFieldKind.number),
  tfo(['tfo'], ProxyFieldKind.toggle),
  mptcp(['mptcp'], ProxyFieldKind.toggle),
  interfaceName(['interface-name']),
  routingMark(['routing-mark'], ProxyFieldKind.number),
  ipVersion(['ip-version'], ProxyFieldKind.choice);

  final List<String> path;
  final ProxyFieldKind kind;

  const ProxyField(this.path, [this.kind = ProxyFieldKind.text]);
}
