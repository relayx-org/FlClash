import 'dart:io';

import 'package:args/args.dart';

import 'src/changelog/builder.dart';
import 'src/changelog/models.dart';
import 'src/changelog/render.dart';

const _repository = 'relayx-org/FlClash';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('root', help: 'Repository root, defaults to the cwd.');
  parser.addCommand('release')
    ..addOption('version', help: 'Authored version to finalize, without the v.')
    ..addOption('date', help: 'Release date, defaults to today for drafts.');
  parser.addCommand('build');
  parser.addCommand('render')
    ..addOption('tag', help: 'Authored version or tag, defaults to the newest.')
    ..addOption('out', help: 'Output file, defaults to stdout.');
  parser
      .addCommand('verify')
      .addOption('version', help: 'Require release notes for this version.');

  try {
    final results = parser.parse(arguments);
    final command = results.command;
    if (command == null) {
      _fail(_usage(parser));
    }
    final root = results.option('root') ?? Directory.current.path;
    final changelog = readChangelog(root);
    final status = switch (command.name) {
      'release' => _release(root, command, changelog),
      'build' => _build(root, changelog),
      'render' => _render(root, command, changelog),
      'verify' => _verify(root, command, changelog),
      _ => _fail(_usage(parser)),
    };
    exit(status);
  } on FormatException catch (error) {
    _fail(error.message);
  } on FileSystemException catch (error) {
    _fail(error.toString());
  } on StateError catch (error) {
    _fail(error.message);
  }
}

int _release(String root, ArgResults command, Changelog changelog) {
  final version = command.option('version');
  if (version == null) {
    _fail('release needs --version, for example --version 0.1.2');
  }
  final selected = changelogVersionFor(changelog, version);
  final released = ChangelogVersion(
    version: selected.version,
    tag: selected.tag,
    date:
        command.option('date') ??
        (selected.prerelease || selected.date.isEmpty
            ? today()
            : selected.date),
    prerelease: false,
    groups: selected.groups,
  );
  final next = Changelog(
    versions: [
      for (final item in changelog.versions)
        if (item == selected) released else item,
    ],
  );
  final problems = validateChangelog(next);
  if (problems.isNotEmpty) {
    _fail(problems.join('\n'));
  }
  resolve(root, changelogDataPath).writeAsStringSync(encodeChangelog(next));
  _writeMarkdown(root, next);
  stdout.writeln('Finalized release notes for ${selected.tag}.');
  return 0;
}

int _build(String root, Changelog changelog) {
  _writeMarkdown(root, changelog);
  stdout.writeln('Rendered $changelogMarkdownPath from $changelogDataPath.');
  return 0;
}

int _render(String root, ArgResults command, Changelog changelog) {
  if (command.rest.isEmpty) {
    _fail('render needs a target: release or telegram');
  }
  if (changelog.versions.isEmpty) {
    _fail('$changelogDataPath has no versions to render');
  }
  final tag = command.option('tag');
  final version = tag == null
      ? changelog.versions.first
      : changelogVersionFor(changelog, tag);
  final output = switch (command.rest.first) {
    'release' => renderRelease(version),
    'telegram' => renderTelegram(
      version,
      moreUrl: tag == null
          ? null
          : 'https://github.com/$_repository/releases/tag/${version.tag}',
    ),
    _ => _fail('Unknown render target: ${command.rest.first}'),
  };
  final out = command.option('out');
  if (out == null) {
    stdout.write(output);
  } else {
    resolve(root, out).writeAsStringSync(output);
  }
  return 0;
}

int _verify(String root, ArgResults command, Changelog changelog) {
  final version = command.option('version');
  if (version != null) {
    changelogVersionFor(changelog, version);
  }
  final markdown = resolve(root, changelogMarkdownPath).readAsStringSync();
  if (!markdown.contains(changelogFrozenMarker) ||
      markdownHead(markdown).trimRight() !=
          renderMarkdown(changelog).trimRight()) {
    _fail(
      '$changelogMarkdownPath does not match $changelogDataPath; run tool/changelog.dart build.',
    );
  }
  stdout.writeln('Release notes are valid and Markdown is up to date.');
  return 0;
}

void _writeMarkdown(String root, Changelog changelog) {
  final file = resolve(root, changelogMarkdownPath);
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  file.writeAsStringSync(mergeMarkdown(renderMarkdown(changelog), existing));
}

String _usage(ArgParser parser) => '''
Usage: dart run tool/changelog.dart <command> [options]

Commands:
  release --version X   Finalize an authored release and render Markdown.
  build                 Render CHANGELOG.md from changelog.json.
  render <release|telegram> [--tag vX] [--out file]
  verify [--version X]  Validate release notes and generated Markdown.

${parser.usage}''';

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}
