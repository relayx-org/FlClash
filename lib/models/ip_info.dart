import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class IpInfo {
  const IpInfo({required this.ip, required this.countryCode});

  final String ip;
  final String countryCode;

  @override
  bool operator ==(Object other) =>
      other is IpInfo && other.ip == ip && other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(ip, countryCode);

  @override
  String toString() => 'IpInfo(ip: $ip, countryCode: $countryCode)';

  static IpInfo fromIpInfoIoJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country': final String country} => IpInfo(
        ip: ip,
        countryCode: country,
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromGeoJsJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(ip: ip, countryCode: countryCode),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpSbJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(ip: ip, countryCode: countryCode),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpWhoIsJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country_code': final String countryCode} =>
        IpInfo(ip: ip, countryCode: countryCode),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromCountryIsJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'country': final String countryCode} => IpInfo(
        ip: ip,
        countryCode: countryCode,
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpAPIJson(Map<String, dynamic> json) {
    return switch (json) {
      {'query': final String ip, 'countryCode': final String countryCode} =>
        IpInfo(ip: ip, countryCode: countryCode),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIdentMeJson(Map<String, dynamic> json) {
    return switch (json) {
      {'ip': final String ip, 'cc': final String countryCode} => IpInfo(
        ip: ip,
        countryCode: countryCode,
      ),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromIpQueryJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'ip': final String ip,
        'location': {'country_code': final String countryCode},
      } =>
        IpInfo(ip: ip, countryCode: countryCode),
      _ => throw const FormatException('invalid json'),
    };
  }

  static IpInfo fromCloudflareTrace(String body) {
    final fields = <String, String>{};
    for (final line in const LineSplitter().convert(body)) {
      final separator = line.indexOf('=');
      if (separator > 0) {
        fields[line.substring(0, separator)] = line.substring(separator + 1);
      }
    }
    return switch (fields) {
      {'ip': final ip, 'loc': final countryCode} => IpInfo(
        ip: ip,
        countryCode: countryCode,
      ),
      _ => throw const FormatException('invalid trace'),
    };
  }
}
