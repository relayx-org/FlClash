enum IpType { residential, mobile, business, hosting }

enum IpQualityLevel { good, normal, risky }

enum IpQualitySource {
  identMe('ident.me'),
  ipApiCom('ip-api.com'),
  ipQuery('ipquery.io'),
  ipLocate('iplocate.io'),
  proxyCheck('proxycheck.io'),
  ipApiIs('ipapi.is');

  const IpQualitySource(this.label);

  final String label;
}

enum IpQualitySourceStatus { noType, timeout, rateLimited, failed, ipMismatch }
