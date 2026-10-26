import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/iping/providers.dart';
import 'package:fl_clash/iping/backend_native.dart';
import 'package:fl_clash/iping/subscription.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'card.dart';
import 'profile_frame.dart';
import 'profile_detail.dart';

typedef _Usage = ({int used, int total, double share});

_Usage? _usageOf(Profile? profile) {
  final info = profile?.subscriptionInfo;
  if (info == null || info.total <= 0) {
    return null;
  }
  final used = info.upload + info.download;
  return (
    used: used,
    total: info.total,
    share: (used / info.total).clamp(0.0, 1.0).toDouble(),
  );
}

DateTime? _expiryOf(Profile? profile) {
  final expire = profile?.subscriptionInfo?.expire ?? 0;
  return expire > 0 ? DateTime.fromMillisecondsSinceEpoch(expire * 1000) : null;
}

void _openProfile(BuildContext context) {
  showSheet<void>(
    context: context,
    builder: (_) => const IpingSubscriptionDetails(),
  );
}

String _sourceOf(BuildContext context, ProfileType type) => switch (type) {
  ProfileType.url => context.appLocalizations.remote,
  ProfileType.file => context.appLocalizations.local,
  ProfileType.custom => context.appLocalizations.custom,
};

class ProfilesCard extends ConsumerWidget {
  const ProfilesCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return DashboardProfileCard(
      name: profile?.realLabel,
      source: profile == null ? null : _sourceOf(context, profile.type),
      updatedAt: profile?.lastUpdateDate,
      expiry: _expiryOf(profile),
      usage: _usageOf(profile),
      sync: profile != null && profile.type == ProfileType.url
          ? const _SyncButton()
          : null,
      summary: const _ConfigStats(),
      onDetails: () => _openProfile(context),
    );
  }
}

class _SyncButton extends ConsumerWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUpdating = ref.watch(
      ipingSessionProvider.select((state) => state.busy),
    );
    if (isUpdating) {
      return const SizedBox.square(
        dimension: 32,
        child: Center(child: CommonCircleLoading(size: 18)),
      );
    }
    return DashboardIconButton(
      glyph: AppGlyphs.sync,
      tooltip: context.appLocalizations.update,
      onPressed: () => ref.read(ipingClientControllerProvider).synchronize(),
    );
  }
}

class _ConfigStats extends ConsumerStatefulWidget {
  const _ConfigStats();

  @override
  ConsumerState<_ConfigStats> createState() => _ConfigStatsState();
}

class _ConfigStatsState extends ConsumerState<_ConfigStats>
    with ConfigCountsWatch<_ConfigStats> {
  @override
  Widget build(BuildContext context) {
    watchConfigCounts();
    final providers = ref.watch(providersProvider);
    final stats = switch (configCounts) {
      final counts? => profileStatsOf(counts, providers),
      null => null,
    };
    return DashboardConfigStats(
      groups: stats?.groups,
      proxies: stats?.proxies,
      rules: stats?.rules,
      failed: configCountsFailed,
    );
  }
}
