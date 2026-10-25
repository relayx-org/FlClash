import 'package:fl_clash/iping/login_layout.dart';
import 'package:fl_clash/iping/site_config.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

class RouterAccessPage extends StatefulWidget {
  const RouterAccessPage({
    super.key,
    required this.loading,
    required this.busy,
    this.error,
    required this.onSubmit,
  });
  final bool loading;
  final bool busy;
  final String? error;
  final Future<void> Function(String key) onSubmit;

  @override
  State<RouterAccessPage> createState() => _RouterAccessPageState();
}

class _RouterAccessPageState extends State<RouterAccessPage> {
  final _key = TextEditingController();
  final _form = GlobalKey<FormState>();

  void _submit() {
    if (!widget.busy && _form.currentState!.validate()) {
      widget.onSubmit(_key.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Scaffold(body: Center(child: CommonCircleLoading()));
    }
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: IpingLoginLayout(
          site: const IpingSiteConfig(),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.routerAccessTitle,
                  style: AppTextStyle.largeTitle.of(context, emphasized: true),
                ),
                const SizedBox(height: 16),
                Text(
                  l.routerAccessHint,
                  style: AppTextStyle.subheadline.of(context),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '/usr/libexec/iping/agent token',
                  style: AppTextStyle.footnote.of(context),
                ),
                const SizedBox(height: 24),
                SecretTextFormField(
                  controller: _key,
                  decoration: InputDecoration(labelText: l.routerAccessKey),
                  maxLength: 64,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l.emptyTip(l.routerAccessKey)
                      : null,
                ),
                const SizedBox(height: 16),
                ErrorBanner(message: widget.error),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.busy ? null : _submit,
                  child: widget.busy
                      ? const CommonCircleLoading(size: 20)
                      : Text(l.submit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }
}
