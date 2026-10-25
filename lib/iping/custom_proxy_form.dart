import 'package:fl_clash/features/form/custom_proxy_editor.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/custom_proxy.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:material_ui/material_ui.dart';

import 'backend_resources.dart';
import 'filters_page.dart';
import 'resource_controller.dart';

class IpingCustomProxyForm extends StatefulWidget {
  const IpingCustomProxyForm({
    super.key,
    required this.proxy,
    required this.isNew,
    required this.controller,
  });
  final IpingCustomProxy proxy;
  final bool isNew;
  final IpingResourceController<IpingCustomProxy, String> controller;

  @override
  State<IpingCustomProxyForm> createState() => _IpingCustomProxyFormState();
}

class _IpingCustomProxyFormState extends State<IpingCustomProxyForm> {
  late CustomProxy _proxy = CustomProxy(
    id: 0,
    definition: Map<String, dynamic>.from(widget.proxy.definition),
    emptyOptions: {
      for (final field in widget.proxy.emptyOptions)
        ProxyField.values.byName(field),
    },
  );
  String? _error;

  IpingCustomProxy _resource(CustomProxy value) => IpingCustomProxy(
    id: widget.proxy.id,
    definition: value.definition,
    emptyOptions: value.emptyOptions.map((field) => field.name),
  );

  bool get _duplicate =>
      widget.controller.items?.any(
        (item) => item.id != widget.proxy.id && item.name == _proxy.name,
      ) ??
      false;

  Future<bool> _save() async {
    final l = AppLocalizations.of(context);
    if (_duplicate) {
      setState(() => _error = l.existsTip(l.name));
      return false;
    }
    final saved = await widget.controller.put(
      _resource(_proxy),
      replacing: widget.isNew ? null : widget.proxy.id,
    );
    if (mounted) {
      setState(
        () => _error = saved
            ? null
            : resourceErrorMessage(
                widget.controller.error,
                l,
                label: l.proxies,
              ),
      );
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) => IpingCustomProxyEditor(
    proxy: _proxy,
    isNew: widget.isNew,
    onChanged: (value) => setState(() {
      _proxy = value;
      _error = null;
    }),
    validate: (value) => widget.controller.store.validate(_resource(value)),
    save: (_) => _save(),
    close: () => Navigator.of(context).pop(),
    nameInvalid: _duplicate || !isIpingResourceName(_proxy.name),
    issuesBuilder: (context, error, submitted) => ErrorBanner(
      message: _error ?? (widget.isNew && !submitted ? null : error),
    ),
  );
}
