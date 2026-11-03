import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api.dart';
import 'providers.dart';
import 'tunnel.dart';

const _qrBackground = Color(0xFFFFFFFF);

Future<void> showIpingSubscriptionExport(
  BuildContext context, {
  required String hint,
  String? warning,
  required Future<String> Function() loadUrl,
}) {
  return showInSheet<void>(
    context,
    builder: (_) => _IpingSubscriptionExportSheet(
      hint: hint,
      warning: warning,
      loadUrl: loadUrl,
    ),
  );
}

Future<void> showIpingTunnelSubscriptionExport(
  BuildContext context,
  WidgetRef ref, {
  required IpingTunnel tunnel,
}) {
  final api = ref.read(ipingAuthenticatedApiProvider);
  return showIpingSubscriptionExport(
    context,
    hint: context.appLocalizations.ipingTunnelSubscriptionHint(tunnel.name),
    loadUrl: () async =>
        api.subscriptionUrl(await api.tunnelSubscriptionToken(tunnel.id)),
  );
}

class _IpingSubscriptionExportSheet extends ConsumerStatefulWidget {
  const _IpingSubscriptionExportSheet({
    required this.hint,
    required this.warning,
    required this.loadUrl,
  });

  final String hint;
  final String? warning;
  final Future<String> Function() loadUrl;

  @override
  ConsumerState<_IpingSubscriptionExportSheet> createState() =>
      _IpingSubscriptionExportSheetState();
}

class _IpingSubscriptionExportSheetState
    extends ConsumerState<_IpingSubscriptionExportSheet> {
  String? _url;
  IpingFailure? _failure;
  var _loading = true;
  var _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final url = await widget.loadUrl();
      if (!mounted || request != _request) return;
      setState(() {
        _url = url;
        _failure = null;
        _loading = false;
      });
    } on IpingException catch (error) {
      _fail(request, error.failure);
    } catch (_) {
      _fail(request, IpingFailure.unavailable);
    }
  }

  void _fail(int request, IpingFailure failure) {
    if (!mounted || request != _request) return;
    setState(() {
      _failure = failure;
      _loading = false;
    });
  }

  void _retry() {
    setState(() {
      _failure = null;
      _loading = true;
    });
    unawaited(_load());
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    context.showNotifier(
      context.appLocalizations.ipingSubscriptionLinkCopied,
      level: MessageLevel.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final url = _url;
    return CommonScaffold(
      title: l.ipingExportSubscription,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            context.contentTopPadding,
            16,
            24 + BottomInsetScope.of(context),
          ),
          children: [
            Text(widget.hint, style: context.listCaptionStyle),
            if (url != null) ...[
              const SizedBox(height: 20),
              Center(
                child: DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: _qrBackground,
                    shape: AppShape.lg,
                  ),
                  child: QrImageView(
                    data: url,
                    size: 200,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: _qrBackground,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(url, style: AppTextStyle.footnote.of(context)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _copy(url),
                child: Text(l.ipingCopySubscriptionLink),
              ),
              const SizedBox(height: 12),
              Text(l.ipingSubscriptionQrHint, style: context.listCaptionStyle),
            ] else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CommonCircleLoading()),
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                _failure == IpingFailure.session
                    ? l.ipingSessionExpired
                    : l.ipingSubscriptionLinkFailed,
                style: AppTextStyle.body
                    .of(context)
                    .copyWith(color: context.colorScheme.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _retry, child: Text(l.retry)),
            ],
            if (widget.warning case final warning?) ...[
              const SizedBox(height: 16),
              Text(
                warning,
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(color: context.colorScheme.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
