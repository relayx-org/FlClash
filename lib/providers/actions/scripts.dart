part of '../action.dart';

@Riverpod(keepAlive: true)
class ScriptsAction extends _$ScriptsAction {
  @override
  void build() {}

  void putScript(Script script) {
    ref.read(scriptsProvider.notifier).put(script);
    _applyIfInUse(script.id);
  }

  Future<Script> saveScript(Script script, String content) async {
    final previous = await script.content;
    final next = await script.save(content);
    try {
      await ref.read(scriptsProvider.notifier).putAsync(next);
    } catch (error, stack) {
      if (previous == null) {
        await File(await next.path).safeDelete();
      } else {
        await File(await next.path).safeWriteAsString(previous);
      }
      Error.throwWithStackTrace(error, stack);
    }
    _applyIfInUse(next.id);
    return next;
  }

  Future<void> delScript(Script script) async {
    await ref.read(scriptsProvider.notifier).delAsync(script.id);
    await File(await script.path).safeDelete();
    _applyIfInUse(script.id);
  }

  Future<void> updateScript(Script script) async {
    final updatingKeys = ref.read(updatingKeysProvider.notifier);
    final operation = updatingKeys.start(script.updatingKey);
    try {
      final response = await request.getTextResponseForUrl(script.url!);
      await saveScript(script, response.data ?? '');
    } finally {
      updatingKeys.stop(script.updatingKey, operation);
    }
  }

  void _applyIfInUse(int scriptId) {
    final profile = ref.read(currentProfileProvider);
    if (profile?.extendType != ExtendType.script ||
        profile?.scriptId != scriptId) {
      return;
    }
    ref.read(setupActionProvider.notifier).applyProfileDebounce(silence: true);
  }
}
