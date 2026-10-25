import '../l10n/l10n.dart';
import 'backend_settings.dart';

String? ipingSettingsErrorMessage(Object error, AppLocalizations l) {
  if (error is! IpingSettingsException) return null;
  final label = switch (error.key) {
    'mixed-port' => l.mixedPort,
    'port' => l.port,
    'socks-port' => l.socksPort,
    'redir-port' => l.redirPort,
    'tproxy-port' => l.tproxyPort,
    'allow-lan' => l.allowLan,
    'unified-delay' => l.unifiedDelay,
    'tcp-concurrent' => l.tcpConcurrent,
    'find-process-mode' => l.findProcessMode,
    'geodata-loader' => l.geodataLoader,
    'log-level' => l.logLevel,
    'global-ua' => l.userAgent,
    'dns.listen' => l.listen,
    'dns.ipv6-timeout' => l.ipv6Timeout,
    'dns.cache-max-size' => l.cacheMaxSize,
    'dns.fake-ip-range' => l.fakeipRange,
    'dns.fake-ip-range6' => l.fakeipRange6,
    'dns.fake-ip-ttl' => l.fakeipTtl,
    'tun.stack' => l.stackMode,
    'tun.dns-hijack' => l.dnsHijacking,
    _ => error.key,
  };
  return switch (error.issue) {
    IpingSettingsIssue.portConflict => l.portConflictTip,
    IpingSettingsIssue.portRange => l.portTip(label),
    IpingSettingsIssue.unsupported ||
    IpingSettingsIssue.invalid => l.invalidSettingTip(label),
  };
}
