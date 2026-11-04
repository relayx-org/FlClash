import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/message_level.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _posterAsset = 'assets/images/iping_referral_poster.webp';
const _fileName = 'iping-referral.png';

/// The poster is authored at this width, so its layout stays put when the
/// asset at [_posterAsset] is replaced at another resolution.
const _posterWidth = 1024.0;

/// The card the poster leaves for the code, in the poster's own pixels.
const _qrBox = Rect.fromLTWH(751, 1136, 224, 224);

/// The card's corner marks, cleared because they would sit in the quiet zone
/// the code needs.
const _cornerMarks = [
  Rect.fromLTWH(748, 1133, 40, 43),
  Rect.fromLTWH(940, 1133, 40, 43),
  Rect.fromLTWH(748, 1322, 40, 43),
  Rect.fromLTWH(940, 1322, 40, 43),
];

/// The card's white in [_posterAsset], so clearing the marks leaves no patch.
const _cardColor = Color(0xFFFEFEFE);

/// A scanner reads the code only with this many light modules around it.
const _quietModules = 4;

String? _posterLink;
Uint8List? _posterBytes;

Future<Uint8List> composeReferralPoster(String link) async {
  final cached = _posterBytes;
  if (cached != null && _posterLink == link) return cached;
  final data = await rootBundle.load(_posterAsset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final poster = (await codec.getNextFrame()).image;
  try {
    final bytes = await _compose(poster, link);
    _posterLink = link;
    _posterBytes = bytes;
    return bytes;
  } finally {
    poster.dispose();
    codec.dispose();
  }
}

Future<Uint8List> _compose(ui.Image poster, String link) async {
  final scale = poster.width / _posterWidth;
  final code = QrImage(
    QrCode.fromData(data: link, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(poster, Offset.zero, Paint());
  final card = Paint()..color = _cardColor;
  for (final mark in _cornerMarks) {
    canvas.drawRect(_scaled(mark, scale), card);
  }
  _paintCode(canvas, code, _scaled(_qrBox, scale));
  final picture = recorder.endRecording();
  final image = await picture.toImage(poster.width, poster.height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Unable to encode the referral poster');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Rect _scaled(Rect rect, double scale) {
  return Rect.fromLTWH(
    rect.left * scale,
    rect.top * scale,
    rect.width * scale,
    rect.height * scale,
  );
}

void _paintCode(Canvas canvas, QrImage code, Rect box) {
  final modules = code.moduleCount;
  final quiet = modules + _quietModules * 2;
  final side = math.max(1, (box.shortestSide / quiet).floor()).toDouble();
  final extent = side * modules;
  final left = (box.center.dx - extent / 2).roundToDouble();
  final top = (box.center.dy - extent / 2).roundToDouble();
  final paint = Paint()
    ..color = const Color(0xFF000000)
    ..isAntiAlias = false;
  for (var y = 0; y < modules; y++) {
    for (var x = 0; x < modules; x++) {
      if (!code.isDark(x, y)) continue;
      canvas.drawRect(
        Rect.fromLTWH(left + x * side, top + y * side, side, side),
        paint,
      );
    }
  }
}

Future<bool> _saveImage(Uint8List bytes) async {
  return await picker.saveFile(_fileName, bytes) != null;
}

Future<void> showIpingReferralShare(
  BuildContext context, {
  required String link,
}) {
  return showInSheet<void>(
    context,
    builder: (_) => IpingReferralShareSheet(link: link),
  );
}

class IpingReferralShareSheet extends StatefulWidget {
  const IpingReferralShareSheet({
    super.key,
    required this.link,
    this.compose = composeReferralPoster,
    this.share = shareImage,
    this.save = _saveImage,
  });

  final String link;
  final Future<Uint8List> Function(String link) compose;
  final Future<bool> Function(
    Uint8List bytes, {
    required String name,
    String? text,
    Rect? origin,
  })
  share;
  final Future<bool> Function(Uint8List bytes) save;

  @override
  State<IpingReferralShareSheet> createState() =>
      _IpingReferralShareSheetState();
}

class _IpingReferralShareSheetState extends State<IpingReferralShareSheet> {
  Uint8List? _bytes;
  var _failed = false;
  var _busy = false;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    final request = ++_request;
    try {
      final bytes = await widget.compose(widget.link);
      if (!mounted || request != _request) return;
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() {
      _bytes = null;
      _failed = false;
    });
    unawaited(_generate());
  }

  Future<void> _run(Future<bool> Function() action, String failure) async {
    setState(() => _busy = true);
    try {
      if (!await action() && mounted) _notify(failure, MessageLevel.error);
    } catch (_) {
      if (mounted) _notify(failure, MessageLevel.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String text, MessageLevel level) {
    context.showNotifier(text, level: level);
  }

  Future<void> _share(BuildContext anchor) async {
    final bytes = _bytes;
    if (bytes == null) return;
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final l = AppLocalizations.of(context);
    await _run(
      () => widget.share(
        bytes,
        name: _fileName,
        text: widget.link,
        origin: origin,
      ),
      l.ipingShareImageFailed,
    );
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final l = AppLocalizations.of(context);
    await _run(() => widget.save(bytes), l.ipingSaveImageFailed);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    _notify(AppLocalizations.of(context).copySuccess, MessageLevel.success);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bytes = _bytes;
    return CommonScaffold(
      title: l.ipingSharePoster,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            if (bytes != null) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: ClipRSuperellipse(
                    borderRadius: AppRadius.lg,
                    child: Image.memory(
                      bytes,
                      cacheWidth: 720,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Builder(
                builder: (context) => FilledButton(
                  onPressed: _busy ? null : () => _share(context),
                  child: Text(l.ipingShareImage),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _save,
                      child: Text(l.ipingSaveImage),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _copy,
                      child: Text(l.copyLink),
                    ),
                  ),
                ],
              ),
            ] else if (_failed) ...[
              const SizedBox(height: 8),
              Text(
                l.ipingShareImageFailed,
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _retry, child: Text(l.retry)),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CommonCircleLoading()),
              ),
          ],
        ),
      ),
    );
  }
}
