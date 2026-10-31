/// Resolves a backend image path against [site]; empty unless it is web.
String ipingImageUrl(String value, {required String site}) {
  final uri = Uri.tryParse(value);
  final resolved = value.isEmpty || uri == null
      ? null
      : Uri.parse(site).resolveUri(uri);
  return resolved != null &&
          (resolved.scheme == 'https' || resolved.scheme == 'http') &&
          resolved.host.isNotEmpty
      ? resolved.toString()
      : '';
}

class IpingSiteConfig {
  const IpingSiteConfig({
    this.name = 'iPing',
    this.description = '',
    this.logoUrl = '',
    this.allowRegister = true,
  });

  final String name;
  final String description;
  final String logoUrl;
  final bool allowRegister;

  factory IpingSiteConfig.fromJson(
    Map<String, dynamic> json, {
    required String site,
  }) {
    String text(String key) => switch (json[key]) {
      final String value => value.trim(),
      _ => '',
    };

    final name = text('SITE_NAME');
    return IpingSiteConfig(
      name: name.isEmpty ? 'iPing' : name,
      description: text('SITE_DESCRIPTION'),
      logoUrl: ipingImageUrl(text('LOGO_URL'), site: site),
      allowRegister: switch (json['ALLOW_REGISTER']) {
        final bool value => value,
        _ => true,
      },
    );
  }

  Map<String, Object> toJson() => {
    'SITE_NAME': name,
    'SITE_DESCRIPTION': description,
    'LOGO_URL': logoUrl,
    'ALLOW_REGISTER': allowRegister,
  };
}
