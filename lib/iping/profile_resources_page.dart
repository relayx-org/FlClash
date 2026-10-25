import 'dart:async';

import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/error_banner.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:material_ui/material_ui.dart';

import 'backend.dart';
import 'filters_page.dart';

class IpingProfileResourcesPage extends StatefulWidget {
  const IpingProfileResourcesPage({super.key, required this.backend});
  final IpingBackend backend;

  @override
  State<IpingProfileResourcesPage> createState() =>
      _IpingProfileResourcesPageState();
}

class _IpingProfileResourcesPageState extends State<IpingProfileResourcesPage> {
  IpingProfileResources? _profile;
  List<IpingCustomProxy> _proxies = const [];
  List<IpingRuleProvider> _providers = const [];
  List<Filter> _filters = const [];
  List<IpingAddedRule> _rules = const [];
  List<IpingScript> _scripts = const [];
  IpingResourceBindings _value = const IpingResourceBindings();
  bool _saving = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _error = null;
      _profile = null;
    });
    try {
      final (profile, proxies, providers, filters, rules, scripts) = await (
        widget.backend.readProfileResources(),
        Future.value(widget.backend.customProxies.read()),
        Future.value(widget.backend.ruleProviders.read()),
        Future.value(widget.backend.filters.read()),
        Future.value(widget.backend.addedRules.read()),
        Future.value(widget.backend.scripts.read()),
      ).wait;
      if (!mounted || request != _request) return;
      setState(() {
        _profile = profile;
        _proxies = proxies;
        _providers = providers;
        _filters = filters;
        _rules = rules;
        _scripts = scripts;
        _value = profile.bindings.copyWith(
          rules: profile.bindings.rules.intersection(
            rules.map((item) => item.id).toSet(),
          ),
          script: scripts.any((item) => item.id == profile.bindings.script)
              ? profile.bindings.script
              : null,
          proxies: profile.bindings.proxies.intersection(
            proxies.map((item) => item.id).toSet(),
          ),
          providers: profile.bindings.providers.intersection(
            providers.map((item) => item.id).toSet(),
          ),
          filters: profile.bindings.filters.intersection(
            filters.map((item) => item.label).toSet(),
          ),
        );
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = resourceErrorMessage(
            error,
            AppLocalizations.of(context),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final profile = _profile;
    if (_saving || profile == null || profile.profileId.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.backend.updateProfileResources(
        IpingProfileResources(
          profileId: profile.profileId,
          label: profile.label,
          bindings: _value,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = resourceErrorMessage(
            error,
            AppLocalizations.of(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section<T>(
    String title,
    List<T> items,
    String Function(T) idOf,
    String Function(T) nameOf,
    Set<String> selected,
    ValueChanged<Set<String>> change,
  ) => SliverMainAxisGroup(
    slivers: [
      SliverToBoxAdapter(child: ListHeader(title: title)),
      if (items.isEmpty)
        SliverToBoxAdapter(
          child: ListFooter(text: AppLocalizations.of(context).nullTip(title)),
        ),
      SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final id = idOf(item);
          void toggle() {
            if (_saving || _profile?.profileId.isEmpty != false) return;
            setState(
              () => change(
                selected.contains(id)
                    ? ({...selected}..remove(id))
                    : {...selected, id},
              ),
            );
          }

          return ItemPositionProvider(
            position: ItemPosition.get(index, items.length),
            child: DecorationListItem(
              title: Text(nameOf(item)),
              onPressed: toggle,
              trailing: CommonCheckBox(
                value: selected.contains(id),
                onChanged: (_) => toggle(),
              ),
            ),
          );
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CommonScaffold(
      title: l.applyResources,
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        tooltip: l.save,
        isLoading: _saving,
        onPressed: _profile == null || _profile!.profileId.isEmpty || _saving
            ? null
            : _save,
      ),
      body: Builder(
        builder: (context) => NullStatusSwitcher(
          isLoading: _profile == null && _error == null,
          child: _profile == null
              ? NullStatus(
                  label: _error,
                  action: TextButton(onPressed: _load, child: Text(l.retry)),
                )
              : AbsorbPointer(
                  absorbing: _saving,
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16)
                            .copyWith(
                              top: context.contentTopPadding,
                              bottom: 20 + BottomInsetScope.of(context),
                            ),
                        sliver: SliverMainAxisGroup(
                          slivers: [
                            SliverToBoxAdapter(
                              child: ErrorBanner(message: _error),
                            ),
                            SliverToBoxAdapter(
                              child: ListFooter(
                                text: _profile!.profileId.isEmpty
                                    ? l.nullTip(l.profiles)
                                    : l.resourceSelectionHint,
                              ),
                            ),
                            if (_profile!.label.isNotEmpty)
                              SliverToBoxAdapter(
                                child: ListHeader(title: _profile!.label),
                              ),
                            _section(
                              l.proxies,
                              _proxies,
                              (item) => item.id,
                              (item) => item.name,
                              _value.proxies,
                              (value) =>
                                  _value = _value.copyWith(proxies: value),
                            ),
                            _section(
                              l.ruleProviders,
                              _providers,
                              (item) => item.id,
                              (item) => item.label,
                              _value.providers,
                              (value) =>
                                  _value = _value.copyWith(providers: value),
                            ),
                            _section(
                              l.filters,
                              _filters,
                              (item) => item.label,
                              (item) => item.label,
                              _value.filters,
                              (value) =>
                                  _value = _value.copyWith(filters: value),
                            ),
                            _section(
                              l.addedRules,
                              _rules,
                              (item) => item.id,
                              (item) => item.value,
                              _value.rules,
                              (value) => _value = _value.copyWith(rules: value),
                            ),
                            _section(
                              l.script,
                              <IpingScript>[
                                const IpingScript(
                                  id: '',
                                  label: '',
                                  content: '',
                                ),
                                ..._scripts,
                              ],
                              (item) => item.id,
                              (item) => item.id.isEmpty ? l.none : item.label,
                              {_value.script ?? ''},
                              (value) => _value = _value.copyWith(
                                script: value.lastOrNull?.isEmpty == false
                                    ? value.last
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
