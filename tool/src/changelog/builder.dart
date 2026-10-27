import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'render.dart';

const changelogDataPath = 'changelog.json';

const changelogMarkdownPath = 'CHANGELOG.md';

final _frozenComment = RegExp(r'\s*<!--.*?-->', dotAll: true);

/// End of the generated head: the frozen marker plus whatever comment lines
/// follow it. Matching comments by shape rather than by text means the note can
/// be reworded without stranding the previous wording in the frozen tail.
int _frozenBoundary(String content) {
  final markerIndex = content.indexOf(changelogFrozenMarker);
  if (markerIndex < 0) {
    return -1;
  }
  var cursor = markerIndex + changelogFrozenMarker.length;
  while (true) {
    final match = _frozenComment.matchAsPrefix(content, cursor);
    if (match == null) {
      return cursor;
    }
    cursor = match.end;
  }
}

String mergeMarkdown(
  String rendered,
  String existing, {
  bool freezeHistory = false,
}) {
  final boundary = _frozenBoundary(existing);
  if (boundary < 0 || freezeHistory) {
    var tail =
        (boundary < 0
                ? existing
                : '${existing.substring(0, existing.indexOf(changelogFrozenMarker)).trimRight()}\n\n'
                      '${existing.substring(boundary).trimLeft()}')
            .trimLeft();
    for (final title in [changelogTitle, '# Changelog']) {
      if (tail.startsWith(title)) {
        tail = tail.substring(title.length).trimLeft();
        break;
      }
    }
    return '$rendered$tail';
  }
  return '$rendered${existing.substring(boundary).trimLeft()}';
}

String markdownHead(String content) {
  final boundary = _frozenBoundary(content);
  return boundary < 0 ? content : content.substring(0, boundary);
}

String encodeChangelog(Changelog changelog) =>
    '${const JsonEncoder.withIndent('  ').convert(changelog.toJson())}\n';

Changelog decodeChangelog(String source) =>
    Changelog.fromJson(jsonDecode(source) as Map<String, dynamic>);

Changelog readChangelog(String root) {
  try {
    final data =
        jsonDecode(resolve(root, changelogDataPath).readAsStringSync())
            as Map<String, dynamic>;
    if (data['schemaVersion'] != changelogSchemaVersion) {
      throw const FormatException('Unsupported changelog schema');
    }
    final changelog = Changelog.fromJson(data);
    final problems = validateChangelog(changelog);
    if (problems.isNotEmpty) {
      throw FormatException(problems.join('\n'));
    }
    return changelog;
  } on TypeError {
    throw const FormatException('Invalid structure in changelog.json');
  }
}

ChangelogVersion changelogVersionFor(Changelog changelog, String value) =>
    changelog.versions.firstWhere(
      (version) => version.tag == value || version.version == value,
      orElse: () => throw StateError(
        'Add release notes for $value to $changelogDataPath first.',
      ),
    );

List<String> validateChangelog(Changelog changelog) {
  final problems = <String>[];
  final versions = <String>{};
  final tags = <String>{};
  for (final version in changelog.versions) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version.version)) {
      problems.add('Invalid version: ${version.version}');
    }
    if (!versions.add(version.version) || !tags.add(version.tag)) {
      problems.add('Duplicate release: ${version.tag}');
    }
    if (version.tag != 'v${version.version}') {
      problems.add('Tag does not match version: ${version.tag}');
    }
    if (version.date.isNotEmpty) {
      final date = DateTime.tryParse(version.date);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(version.date) ||
          date == null ||
          date.toIso8601String().split('T').first != version.date) {
        problems.add('Invalid release date: ${version.date}');
      }
    }
    final groups = <ChangelogType>{};
    for (final group in version.groups) {
      if (!groups.add(group.type)) {
        problems.add('Duplicate group in ${version.tag}: ${group.type.id}');
      }
      for (final entry in group.entries) {
        if (entry.text.trim().isEmpty) {
          problems.add('Empty release note in ${version.tag}');
        }
      }
    }
  }
  return problems;
}

String today() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

File resolve(String root, String path) {
  final separator = Platform.pathSeparator;
  if (path.startsWith(separator) || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
    return File(path);
  }
  return File('$root$separator$path');
}
