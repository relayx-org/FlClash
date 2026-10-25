const _shareLinkSchemes = {
  'hysteria',
  'hysteria2',
  'hy2',
  'hysteria2+realm',
  'hy2+realm',
  'tuic',
  'trojan',
  'vless',
  'vmess',
  'ss',
  'ssr',
  'socks',
  'socks5',
  'socks5h',
  'anytls',
  'mierus',
};

bool isShareLink(String value) {
  final index = value.indexOf('://');
  return index > 0 &&
      value.length > index + 3 &&
      !value.contains('\n') &&
      _shareLinkSchemes.contains(value.substring(0, index).toLowerCase());
}
