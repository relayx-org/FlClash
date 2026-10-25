import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/resource_bindings.freezed.dart';
part 'generated/resource_bindings.g.dart';

@freezed
abstract class IpingResourceBindings with _$IpingResourceBindings {
  const IpingResourceBindings._();

  const factory IpingResourceBindings({
    @Default({}) Set<String> proxies,
    @Default({}) Set<String> providers,
    @Default({}) Set<String> filters,
    @Default({}) Set<String> rules,
    String? script,
  }) = _IpingResourceBindings;

  factory IpingResourceBindings.fromJson(Map<String, Object?> json) =>
      _$IpingResourceBindingsFromJson(json);

  bool get isEmpty =>
      proxies.isEmpty &&
      providers.isEmpty &&
      filters.isEmpty &&
      rules.isEmpty &&
      script == null;
}
