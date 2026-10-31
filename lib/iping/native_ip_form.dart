import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'country_continent.dart';
import 'native_ip.dart';
import 'providers.dart';
import 'topup.dart';

const _months = [1, 3, 6, 12];

String nativeIpLineLabel(AppLocalizations l, NativeIpLine line) =>
    switch (line) {
      NativeIpLine.a => l.ipingNativeIpLineA,
      NativeIpLine.b => l.ipingNativeIpLineB,
      NativeIpLine.c => l.ipingNativeIpLineC,
    };

String nativeIpMonthLabel(AppLocalizations l, int months) =>
    months == 1 ? l.ipingNativeIpOneMonth : l.ipingNativeIpMonths(months);

/// Completes with the order once the backend accepts it.
Future<NativeIpOrder?> showIpingNativeIpPurchase(
  BuildContext context, {
  required NativeIpOffer offer,
  required List<TunnelPlan> plans,
}) => showFormSheet<NativeIpOrder>(
  context: context,
  builder: (_) => _IpingNativeIpForm(offer: offer, plans: plans),
);

class _IpingNativeIpForm extends ConsumerStatefulWidget {
  const _IpingNativeIpForm({required this.offer, required this.plans});

  final NativeIpOffer offer;
  final List<TunnelPlan> plans;

  @override
  ConsumerState<_IpingNativeIpForm> createState() => _IpingNativeIpFormState();
}

class _IpingNativeIpFormState extends ConsumerState<_IpingNativeIpForm> {
  final _count = TextEditingController(text: '1');
  var _monthsSelected = 1;
  int? _planId;
  var _attempted = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _planId = widget.plans.firstOrNull?.id;
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  int? get _quantity {
    final value = int.tryParse(_count.text.trim());
    if (value == null || value < 1) return null;
    return value;
  }

  TunnelPlan? get _plan {
    if (widget.plans.isEmpty) return null;
    return widget.plans.where((plan) => plan.id == _planId).firstOrNull ??
        widget.plans.first;
  }

  bool get _countInvalid {
    final quantity = _quantity;
    return quantity == null || quantity > widget.offer.stock;
  }

  String? _issue() {
    final l = context.appLocalizations;
    if (_countInvalid) return l.ipingNativeIpCountInvalid(widget.offer.stock);
    if (_plan == null) return l.ipingNativeIpNoPlans;
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _attempted = true;
      _error = null;
    });
    if (_issue() != null) return;
    final plan = _plan;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final order = await ref
          .read(ipingAuthenticatedApiProvider)
          .buyNativeIp(
            NativeIpPurchase(
              offer: widget.offer,
              months: _monthsSelected,
              count: _quantity!,
              tunnelPlanId: plan?.id,
            ),
          );
      ref.invalidate(ipingNativeIpInventoryProvider);
      ref.invalidate(ipingUserInfoProvider);
      if (mounted) Navigator.of(context).pop(order);
    } on IpingException catch (error) {
      if (mounted) {
        _error =
            error.message ??
            context.appLocalizations.ipingNativeIpPurchaseFailed;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed([String? _]) => setState(() => _error = null);

  double? _total(TunnelPlan? plan) {
    final quantity = _quantity;
    if (quantity == null || quantity > widget.offer.stock) return null;
    final ip = widget.offer.price * _monthsSelected * quantity;
    final tunnel = (plan?.price ?? 0) * quantity;
    return ip + tunnel;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final scheme = context.colorScheme;
    final offer = widget.offer;
    final plan = _plan;
    final total = _total(plan);
    final plans = widget.plans;
    final flag = countryFlagEmoji(offer.countryCode);
    return FormPage(
      title: l.ipingNativeIpBuy,
      saveLabel: l.ipingNativeIpBuy,
      saving: _saving,
      error: _error ?? (_attempted ? _issue() : null),
      onSave: _submit,
      children: [
        AbsorbPointer(
          absorbing: _saving,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              generateSection(
                items: [
                  ListItem(
                    leading: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: flag == null
                            ? Text(
                                offer.countryCode.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyle.caption1
                                    .of(context, emphasized: true)
                                    .copyWith(color: scheme.onSurfaceVariant),
                              )
                            : EmojiText(
                                flag,
                                style: AppTextStyle.title3.of(context),
                              ),
                      ),
                    ),
                    title: Text(offer.place),
                    subtitle: Text(
                      l.ipingNativeIpMonthly(ipingCurrency(offer.price)),
                    ),
                  ),
                ],
              ),
              generateSection(
                title: l.ipingNativeIpOrder,
                items: [
                  ListItem.options(
                    title: Text(l.ipingNativeIpDuration),
                    options: _months,
                    value: _monthsSelected,
                    textBuilder: (months) => nativeIpMonthLabel(l, months),
                    onChanged: (months) => setState(() {
                      _monthsSelected = months;
                      _error = null;
                    }),
                  ),
                  FormRow(
                    title: l.ipingNativeIpCount,
                    invalid: _attempted && _countInvalid,
                    trailing: FormRowTextField(
                      controller: _count,
                      hintText: '1–${offer.stock}',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _changed,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                  if (plans.isNotEmpty)
                    ListItem.options(
                      title: Text(l.ipingNativeIpPlan),
                      subtitle: plan == null
                          ? null
                          : Text(
                              '${ipingCurrency(plan.price)} · '
                              '${ipingGigabytes(plan.traffic)}',
                            ),
                      options: plans,
                      value: plan ?? plans.first,
                      textBuilder: (item) => item.name,
                      onChanged: (item) => setState(() {
                        _planId = item.id;
                        _error = null;
                      }),
                    )
                  else
                    ListItem(
                      title: Text(l.ipingNativeIpPlan),
                      subtitle: Text(l.ipingNativeIpNoPlans),
                    ),
                  if (total != null)
                    FormRow(
                      title: l.ipingNativeIpTotal,
                      trailing: Text(ipingCurrency(total)),
                    ),
                ],
                footer: offer.line == NativeIpLine.b
                    ? l.ipingNativeIpConfigureNow
                    : l.ipingNativeIpConfigureLater,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
