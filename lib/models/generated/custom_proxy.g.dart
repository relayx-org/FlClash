// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../custom_proxy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomProxy _$CustomProxyFromJson(Map<String, dynamic> json) => _CustomProxy(
  id: Snowflake.buildId((json['id'] as num?)?.toInt()),
  definition: json['definition'] as Map<String, dynamic>? ?? const {},
  order: json['order'] as String?,
  emptyOptions:
      (json['emptyOptions'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$ProxyFieldEnumMap, e))
          .toSet() ??
      const {},
);

Map<String, dynamic> _$CustomProxyToJson(_CustomProxy instance) =>
    <String, dynamic>{
      'id': instance.id,
      'definition': instance.definition,
      'order': instance.order,
      'emptyOptions': instance.emptyOptions
          .map((e) => _$ProxyFieldEnumMap[e]!)
          .toList(),
    };

const _$ProxyFieldEnumMap = {
  ProxyField.username: 'username',
  ProxyField.password: 'password',
  ProxyField.uuid: 'uuid',
  ProxyField.psk: 'psk',
  ProxyField.key: 'key',
  ProxyField.privateKey: 'privateKey',
  ProxyField.publicKey: 'publicKey',
  ProxyField.privateKeyPassphrase: 'privateKeyPassphrase',
  ProxyField.preSharedKey: 'preSharedKey',
  ProxyField.authStr: 'authStr',
  ProxyField.cipher: 'cipher',
  ProxyField.alterId: 'alterId',
  ProxyField.protocol: 'protocol',
  ProxyField.obfs: 'obfs',
  ProxyField.transport: 'transport',
  ProxyField.up: 'up',
  ProxyField.down: 'down',
  ProxyField.network: 'network',
  ProxyField.flow: 'flow',
  ProxyField.wsPath: 'wsPath',
  ProxyField.wsHost: 'wsHost',
  ProxyField.grpcServiceName: 'grpcServiceName',
  ProxyField.xhttpPath: 'xhttpPath',
  ProxyField.xhttpHost: 'xhttpHost',
  ProxyField.tls: 'tls',
  ProxyField.sni: 'sni',
  ProxyField.servername: 'servername',
  ProxyField.alpn: 'alpn',
  ProxyField.skipCertVerify: 'skipCertVerify',
  ProxyField.clientFingerprint: 'clientFingerprint',
  ProxyField.realityPublicKey: 'realityPublicKey',
  ProxyField.realityShortId: 'realityShortId',
  ProxyField.plugin: 'plugin',
  ProxyField.pluginMode: 'pluginMode',
  ProxyField.pluginHost: 'pluginHost',
  ProxyField.udpOverTcp: 'udpOverTcp',
  ProxyField.protocolParam: 'protocolParam',
  ProxyField.obfsParam: 'obfsParam',
  ProxyField.obfsPassword: 'obfsPassword',
  ProxyField.obfsSecret: 'obfsSecret',
  ProxyField.obfsMode: 'obfsMode',
  ProxyField.obfsHost: 'obfsHost',
  ProxyField.version: 'version',
  ProxyField.ports: 'ports',
  ProxyField.hopInterval: 'hopInterval',
  ProxyField.congestionController: 'congestionController',
  ProxyField.udpRelayMode: 'udpRelayMode',
  ProxyField.reduceRtt: 'reduceRtt',
  ProxyField.ip: 'ip',
  ProxyField.ipv6: 'ipv6',
  ProxyField.allowedIps: 'allowedIps',
  ProxyField.dns: 'dns',
  ProxyField.remoteDnsResolve: 'remoteDnsResolve',
  ProxyField.mtu: 'mtu',
  ProxyField.tfo: 'tfo',
  ProxyField.mptcp: 'mptcp',
  ProxyField.interfaceName: 'interfaceName',
  ProxyField.routingMark: 'routingMark',
  ProxyField.ipVersion: 'ipVersion',
};
