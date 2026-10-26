import 'package:fl_clash/common/ip_quality.dart';
import 'package:fl_clash/models/ip_quality.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/record.dart';
import 'package:material_ui/material_ui.dart';

import 'labels.dart';

class IpQualityDetail extends StatelessWidget {
  const IpQualityDetail({
    super.key,
    required this.ip,
    required this.isLoading,
    this.quality,
    this.error,
    this.address,
    this.other = const [],
  });

  final bool isLoading;
  final IpQuality? quality;
  final Object? error;
  final Widget? address;
  final List<Widget> other;

  /// The optical edge of the xl-radius cards, as in the memory sheet.
  static const _tipInset = 5.0;

  final String ip;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final quality = this.quality;
    final error = this.error;
    final failed = quality == null && !isLoading;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(bottom: 20, top: context.contentTopPadding),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_tipInset, 8, _tipInset, 0),
          child: Text(
            localizations.detectionTip,
            style: AppTextStyle.body
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ),
        generateSection(
          title: localizations.basicInfo,
          items: [
            RecordDetailRow(
              title: localizations.ipAddress,
              copyText: ip,
              value: address ?? Text(ip),
            ),
            if (failed)
              RecordDetailRow(
                title: localizations.ipType,
                value: Text(
                  localizations.ipQualityFailed,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              )
            else
              ..._qualityRows(context, quality),
          ],
        ),
        if (!failed)
          generateSection(
            title: localizations.network,
            items: _networkRows(context, quality),
          ),
        if (failed && error is IpQualityLookupException)
          generateSection(
            title: localizations.ipQualitySources,
            items: [
              for (final failure in error.failures)
                RecordDetailRow(
                  title: failure.source.label,
                  value: Text(failure.status.label(context)),
                ),
            ],
          ),
        if (other.isNotEmpty)
          generateSection(title: localizations.other, items: other),
      ],
    );
  }

  /// A lookup still running lays out every row it will fill, so the page
  /// keeps its height when the values arrive.
  List<Widget> _qualityRows(BuildContext context, IpQuality? quality) {
    final localizations = AppLocalizations.of(context);
    if (quality == null) {
      return [
        RecordDetailRow(
          title: localizations.ipQualityLevel,
          value: const SkeletonText(width: 40),
        ),
        RecordDetailRow(
          title: localizations.ipType,
          value: const SkeletonText(width: 64),
        ),
        RecordDetailRow(
          title: localizations.ipFlags,
          value: const SkeletonText(width: 40),
        ),
      ];
    }
    final flags = [
      if (quality.isTor) localizations.ipFlagTor,
      if (quality.isAbuser) localizations.ipFlagAbuser,
      if (quality.isVpn) localizations.ipFlagVpn,
      if (quality.isProxy) localizations.ipFlagProxy,
    ];
    return [
      RecordDetailRow(
        title: localizations.ipQualityLevel,
        value: Text(
          quality.level.label(context),
          style: TextStyle(color: quality.level.color(context)),
        ),
      ),
      RecordDetailRow(
        title: localizations.ipType,
        value: Text(quality.type.label(context)),
      ),
      RecordDetailRow(
        title: localizations.ipFlags,
        value: flags.isEmpty
            ? Text(localizations.none)
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [for (final flag in flags) MetaChip(label: flag)],
              ),
      ),
    ];
  }

  List<Widget> _networkRows(BuildContext context, IpQuality? quality) {
    final localizations = AppLocalizations.of(context);
    Widget valueOf(String? text, {required double width}) =>
        switch ((quality, text)) {
          (null, _) => SkeletonText(width: width),
          (_, final text?) => Text(text),
          _ => const Text('—'),
        };
    final organization = quality?.organization;
    final asn = switch (quality?.asn) {
      final asn? => 'AS$asn',
      null => null,
    };
    return [
      RecordDetailRow(
        title: localizations.ipOrganization,
        copyText: organization,
        value: valueOf(organization, width: 120),
      ),
      RecordDetailRow(
        title: localizations.ipAsn,
        copyText: asn,
        value: valueOf(asn, width: 56),
      ),
      RecordDetailRow(
        title: localizations.ipQualitySource,
        value: valueOf(quality?.source.label, width: 72),
      ),
    ];
  }
}
