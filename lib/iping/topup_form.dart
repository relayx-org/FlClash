import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form_page.dart';
import 'package:fl_clash/features/form/form_row.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'brand_image_native.dart'
    if (dart.library.js_interop) 'brand_image_web.dart';
import 'providers.dart';
import 'topup.dart';

const _presets = [10.0, 30.0, 50.0, 100.0, 200.0, 500.0];

String _plain(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

String _shortCurrency(double value) => '¥${_plain(value)}';

/// Completes with true once an order is created and its payment page opened.
Future<bool?> showIpingTopup(BuildContext context) => showFormSheet<bool>(
  context: context,
  builder: (_) => const IpingTopupForm(),
);

class IpingTopupForm extends ConsumerStatefulWidget {
  const IpingTopupForm({super.key});

  @override
  ConsumerState<IpingTopupForm> createState() => _IpingTopupFormState();
}

class _IpingTopupFormState extends ConsumerState<IpingTopupForm> {
  final _amount = TextEditingController();
  int? _paymentId;
  var _attempted = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _price => double.tryParse(_amount.text.trim());

  bool _amountInvalid(IpingTopupOptions options) {
    final price = _price;
    return price == null || price <= 0 || price < options.minAmount;
  }

  IpingPayment? _payment(IpingTopupOptions options) =>
      options.payments.where((p) => p.id == _paymentId).firstOrNull ??
      options.payments.firstOrNull;

  String? _issue(IpingTopupOptions options) {
    final l = context.appLocalizations;
    if (_amountInvalid(options)) {
      return l.ipingTopupBelowMinimum(_shortCurrency(options.minAmount));
    }
    if (_payment(options) == null) return l.ipingNoPaymentMethods;
    return null;
  }

  void _changed([String? _]) => setState(() => _error = null);

  void _select(double amount) {
    _amount.text = _plain(amount);
    _changed();
  }

  Future<void> _submit(IpingTopupOptions options) async {
    if (_saving) return;
    final l = context.appLocalizations;
    setState(() {
      _attempted = true;
      _error = null;
    });
    final payment = _payment(options);
    if (_issue(options) != null || payment == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final url = await ref
          .read(ipingAuthenticatedApiProvider)
          .createTopup(price: _price!, paymentId: payment.id);
      ref.invalidate(ipingRecentTopupsProvider);
      unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
      dialogs.showNotifier(l.ipingTopupOpened);
      if (mounted) Navigator.of(context).pop(true);
    } on IpingException catch (error) {
      if (mounted) {
        _error = error.status == 409
            ? l.ipingTopupPendingExists
            : l.ipingTopupFailed;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _activities(IpingTopupOptions options) {
    final l = context.appLocalizations;
    if (options.activities.isEmpty) return null;
    return [
      for (final activity in options.activities)
        [
          if (activity.minAmount case final min?)
            l.ipingTopupActivityFrom(_shortCurrency(min)),
          if (activity.maxAmount case final max?)
            l.ipingTopupActivityUpTo(_shortCurrency(max)),
          activity.percentage
              ? l.ipingTopupActivityPercent(_plain(activity.value))
              : l.ipingTopupActivityFixed(_shortCurrency(activity.value)),
        ].join(' · '),
    ].join('\n');
  }

  String? _fee(IpingPayment payment) {
    final parts = [
      if (payment.percentFee > 0) '${_plain(payment.percentFee * 100)}%',
      if (payment.fixedFee > 0) _shortCurrency(payment.fixedFee),
    ];
    return parts.isEmpty
        ? null
        : context.appLocalizations.ipingPaymentFee(parts.join(' + '));
  }

  List<Widget> _fields(IpingTopupOptions options) {
    final l = context.appLocalizations;
    final price = _price;
    final bonus = price == null ? 0.0 : options.bonusFor(price);
    final payment = _payment(options);
    final presets = [
      for (final preset in _presets)
        if (preset >= options.minAmount) preset,
    ];
    return [
      ListHeader(title: l.ipingTopupAmount),
      _AmountGrid(
        amounts: presets.isEmpty ? [options.minAmount] : presets,
        selected: price,
        bonusFor: options.bonusFor,
        onSelected: _select,
      ),
      const SizedBox(height: 8),
      generateSection(
        items: [
          FormRow(
            title: l.ipingTopupOtherAmount,
            invalid: _attempted && _amountInvalid(options),
            trailing: FormRowTextField(
              controller: _amount,
              hintText: l.ipingTopupMinimum(_shortCurrency(options.minAmount)),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                ),
              ],
              onChanged: _changed,
              onFieldSubmitted: (_) => _submit(options),
            ),
          ),
          if (price != null && bonus > 0)
            FormRow(
              title: l.ipingTopupCredited,
              trailing: Text(
                '${ipingCurrency(price + bonus)} · '
                '${l.ipingTopupBonus(ipingCurrency(bonus))}',
              ),
            ),
        ],
        footer: _activities(options),
      ),
      generateSection(
        title: l.ipingPaymentMethod,
        items: [
          for (final item in options.payments)
            DecorationListItem(
              onPressed: () => setState(() {
                _paymentId = item.id;
                _error = null;
              }),
              leading: item.icon.isEmpty ? null : _PaymentIcon(src: item.icon),
              title: Text(item.name),
              subtitle: switch (_fee(item)) {
                final fee? => Text(fee),
                null => null,
              },
              trailing: item == payment ? const SelectionCheck() : null,
            ),
          if (options.payments.isEmpty)
            ListItem(title: Text(l.ipingNoPaymentMethods)),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final options = ref.watch(ipingTopupOptionsProvider);
    final value = options.value;
    final failed = value == null && options.hasError;
    return FormPage(
      title: l.ipingTopUp,
      saveLabel: l.ipingTopupPay,
      saving: _saving || value == null && options.isLoading,
      error: failed
          ? l.ipingTopupOptionsFailed
          : _attempted && value != null
          ? _issue(value) ?? _error
          : _error,
      onSave: () => value == null
          ? ref.invalidate(ipingTopupOptionsProvider)
          : _submit(value),
      children: [
        if (value != null)
          AbsorbPointer(
            absorbing: _saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _fields(value),
            ),
          ),
      ],
    );
  }
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.amounts,
    required this.selected,
    required this.bonusFor,
    required this.onSelected,
  });
  final List<double> amounts;
  final double? selected;
  final double Function(double amount) bonusFor;
  final ValueChanged<double> onSelected;
  static const _columns = 3;
  static const _gap = 8.0;
  @override
  Widget build(BuildContext context) {
    final hasBonus = amounts.any((amount) => bonusFor(amount) > 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final amount in amounts)
              SizedBox(
                width: width,
                child: _AmountTile(
                  amount: amount,
                  bonus: hasBonus ? bonusFor(amount) : null,
                  selected: amount == selected,
                  onPressed: () => onSelected(amount),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.amount,
    required this.bonus,
    required this.selected,
    required this.onPressed,
  });
  final double amount;

  /// Null when no preset has a bonus; zero keeps the line so tiles align.
  final double? bonus;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final bonus = this.bonus;
    return CommonCard(
      isSelected: selected,
      fillsSelection: true,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _shortCurrency(amount),
              maxLines: 1,
              style: AppTextStyle.headline
                  .of(context)
                  .toTabular
                  .copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
            ),
            if (bonus != null)
              Text(
                bonus > 0
                    ? context.appLocalizations.ipingTopupBonus(
                        _shortCurrency(bonus),
                      )
                    : ' ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.src});
  final String src;
  static const _size = 24.0;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: _size,
      child: loadBrandImage(src, const SizedBox.shrink()),
    ),
  );
}
