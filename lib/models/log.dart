import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../enum/log_level.dart';
import '../common/search.dart';

part 'generated/log.freezed.dart';
part 'generated/log.g.dart';

final _logTime = RegExp(r'time="([^"]*)"');
final _logLevel = RegExp(r'level=(\w+)');
final _logMessage = RegExp(r'msg=(".*")$');

String _logDateTime(dynamic _) {
  return DateTime.now().toLocal().toString().substring(0, 19);
}

@freezed
abstract class Log with _$Log {
  const factory Log({
    @JsonKey(name: 'LogLevel') @Default(LogLevel.info) LogLevel logLevel,
    @JsonKey(name: 'Payload') @Default('') String payload,
    @JsonKey(fromJson: _logDateTime) required String dateTime,
  }) = _Log;

  factory Log.app(String payload) {
    return Log(payload: payload, dateTime: _logDateTime(null));
  }

  factory Log.fromJson(Map<String, Object?> json) => _$LogFromJson(json);

  factory Log.fromLine(String line) {
    final time = _logTime.firstMatch(line)?.group(1) ?? '';
    final level = _logLevel.firstMatch(line)?.group(1) ?? 'info';
    final raw = _logMessage.firstMatch(line)?.group(1);
    var payload = line;
    if (raw != null) {
      try {
        payload = jsonDecode(raw) as String;
      } on FormatException {
        payload = raw;
      }
    }
    return Log(
      dateTime: time,
      logLevel: LogLevel.values.firstWhere(
        (value) => value.name == (level == 'warn' ? 'warning' : level),
        orElse: () => LogLevel.info,
      ),
      payload: payload,
    );
  }
}

@freezed
abstract class LogsState with _$LogsState {
  const factory LogsState({
    @Default([]) List<Log> logs,
    @Default([]) List<String> keywords,
    @Default('') String query,
    @Default(true) bool autoScrollToEnd,
  }) = _LogsState;
}

final _logSearchTexts = Expando<String>();

extension LogsStateExt on LogsState {
  bool get isSearching => keywords.isNotEmpty || SearchQuery(query).isNotEmpty;

  List<Log> get list {
    final searchQuery = SearchQuery(query);
    if (keywords.isEmpty && searchQuery.isEmpty) {
      return logs;
    }
    return logs
        .where(
          (log) => keywords.every((keyword) => keyword == log.logLevel.name),
        )
        .whereMatches(
          searchQuery,
          (log) => [log.payload, log.logLevel.name],
          texts: _logSearchTexts,
        )
        .toList();
  }
}
