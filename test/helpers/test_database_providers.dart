import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';

class TestScripts extends Scripts {
  final List<Script> initial;

  TestScripts([this.initial = const []]);

  @override
  Stream<List<Script>> build() => Stream.value(initial);

  @override
  Future<List<Script>> resourceSnapshot() async => state.value ?? initial;
}

class TestGlobalRules extends GlobalRules {
  final List<Rule> initial;

  TestGlobalRules([this.initial = const []]);

  @override
  Stream<List<Rule>> build() => Stream.value(initial);

  @override
  Future<List<Rule>> resourceSnapshot() async => state.value ?? initial;
}

class TestIconSets extends IconSets {
  final List<IconSet> initial;

  TestIconSets([this.initial = const []]);

  @override
  Stream<List<IconSet>> build() => Stream.value(initial);
}

class TestClashProviders extends ClashProviders {
  final List<ClashProvider> initial;

  TestClashProviders([this.initial = const []]);

  @override
  Stream<List<ClashProvider>> build() => Stream.value(initial);

  @override
  Future<List<ClashProvider>> resourceSnapshot() async =>
      state.value ?? initial;
}
