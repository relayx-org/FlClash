import '../enum/page_label.dart';
import '../ui/icons/icons.dart';

extension PageLabelIcon on PageLabel {
  Glyph get glyph => switch (this) {
    PageLabel.dashboard => AppGlyphs.dashboard,
    PageLabel.proxies => AppGlyphs.proxies,
    PageLabel.profiles => AppGlyphs.profiles,
    PageLabel.account => AppGlyphs.account,
    PageLabel.nativeIp => AppGlyphs.locate,
    PageLabel.tunnels => AppGlyphs.swap,
    PageLabel.tools => AppGlyphs.settings,
    PageLabel.logs => AppGlyphs.logs,
    PageLabel.requests => AppGlyphs.requests,
    PageLabel.resources => AppGlyphs.resources,
    PageLabel.connections => AppGlyphs.connections,
    PageLabel.dns => AppGlyphs.dns,
  };
}
