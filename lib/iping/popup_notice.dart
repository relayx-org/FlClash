import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'providers.dart';

const ipingPopupNoticeCooldown = Duration(hours: 2);
const ipingPopupNoticeShownKey = 'my.iping.client.popup-notice.shown';

class IpingPopupNotice extends ConsumerStatefulWidget {
  const IpingPopupNotice({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<IpingPopupNotice> createState() => _IpingPopupNoticeState();
}

class _IpingPopupNoticeState extends ConsumerState<IpingPopupNotice>
    with WidgetsBindingObserver {
  bool _checking = false;
  DateTime? _lastResumeCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(
      ipingSessionProvider.select((state) => state.account?.apiKey),
      (_, apiKey) {
        if (apiKey != null) unawaited(_check());
      },
      fireImmediately: true,
    );
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final shown = preferences.getInt(ipingPopupNoticeShownKey);
      if (shown != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(shown),
              ) <
              ipingPopupNoticeCooldown) {
        return;
      }
      final notice = await ref
          .read(ipingAuthenticatedApiProvider)
          .popupNotice();
      await WidgetsBinding.instance.endOfFrame;
      final navigatorContext = rootNavigatorKey.currentContext;
      if (!mounted ||
          notice.isEmpty ||
          ref.read(ipingSessionProvider).account?.apiKey == null ||
          navigatorContext == null ||
          !navigatorContext.mounted) {
        return;
      }
      await dialogs.showCommonDialog<void>(
        context: navigatorContext,
        child: IpingPopupNoticeDialog(notice: notice),
      );
      await preferences.setInt(
        ipingPopupNoticeShownKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      commonPrint.log('Unable to load popup notice');
    } finally {
      _checking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ref.read(ipingSessionProvider).account?.apiKey == null) return;
    final now = DateTime.now();
    if (_lastResumeCheck != null &&
        now.difference(_lastResumeCheck!) < const Duration(minutes: 5)) {
      return;
    }
    _lastResumeCheck = now;
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class IpingPopupNoticeDialog extends StatelessWidget {
  const IpingPopupNoticeDialog({super.key, required this.notice});
  final String notice;

  void _openLink(String? href) {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return CommonDialog(
      title: l.ipingPopupNoticeTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.ipingPopupNoticeConfirm),
        ),
      ],
      child: MarkdownBody(
        data: notice,
        onTapLink: (_, href, _) => _openLink(href),
      ),
    );
  }
}
