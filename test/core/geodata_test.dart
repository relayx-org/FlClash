import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/core/geodata.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw FlutterError('Missing asset: $key');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Map<String, List<int>> assets;

  void snapshot(String version) {
    final files = <String, Object>{};
    for (final name in [
      'GEOIP.metadb',
      'GEOIP.dat',
      'GEOSITE.dat',
      'ASN.mmdb',
    ]) {
      final bytes = utf8.encode('$name-$version');
      assets['assets/data/$name'] = bytes;
      files[name] = {
        'sha256': sha256.convert(bytes).toString(),
        'size': bytes.length,
      };
    }
    assets['assets/data/manifest.json'] = utf8.encode(
      jsonEncode({'files': files}),
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bundled-geodata-');
    assets = {};
    snapshot('first');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'a package replaces old or damaged files before Core initialization',
    () async {
      final database = File(p.join(directory.path, 'GEOIP.metadb'));
      await database.writeAsString('damaged download');
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'GEOIP.metadb-first');
      for (final name in ['GEOIP.dat', 'GEOSITE.dat', 'ASN.mmdb']) {
        expect(
          await File(p.join(directory.path, name)).readAsString(),
          '$name-first',
        );
      }
    },
  );

  test(
    'online updates survive restart and the next package updates the snapshot',
    () async {
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      final database = File(p.join(directory.path, 'GEOIP.metadb'));
      await database.writeAsString('manual online update');
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'manual online update');
      snapshot('next');
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'GEOIP.metadb-next');
      await database.delete();
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'GEOIP.metadb-next');
    },
  );

  test(
    'a damaged bundle leaves the installed database intact and can be retried',
    () async {
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      snapshot('next');
      final valid = assets['assets/data/GEOIP.metadb']!;
      assets['assets/data/GEOIP.metadb'] = utf8.encode('truncated');
      await expectLater(
        installBundledGeodata(directory.path, bundle: _Bundle(assets)),
        throwsFormatException,
      );
      final database = File(p.join(directory.path, 'GEOIP.metadb'));
      expect(await database.readAsString(), 'GEOIP.metadb-first');
      assets['assets/data/GEOIP.metadb'] = valid;
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'GEOIP.metadb-next');
    },
  );

  test(
    'development assets without a manifest only fill missing databases',
    () async {
      assets.remove('assets/data/manifest.json');
      final database = File(p.join(directory.path, 'GEOIP.metadb'));
      await database.writeAsString('existing');
      await installBundledGeodata(directory.path, bundle: _Bundle(assets));
      expect(await database.readAsString(), 'existing');
      expect(
        await File(p.join(directory.path, 'ASN.mmdb')).readAsString(),
        'ASN.mmdb-first',
      );
    },
  );
}
