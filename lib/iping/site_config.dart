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
    final logo = text('LOGO_URL');
    final uri = Uri.tryParse(logo);
    final resolved = logo.isEmpty || uri == null
        ? null
        : Uri.parse(site).resolveUri(uri);
    return IpingSiteConfig(
      name: name.isEmpty ? 'iPing' : name,
      description: text('SITE_DESCRIPTION'),
      logoUrl:
          resolved != null &&
              (resolved.scheme == 'https' || resolved.scheme == 'http') &&
              resolved.host.isNotEmpty
          ? resolved.toString()
          : '',
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
