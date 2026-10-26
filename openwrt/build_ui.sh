#!/bin/sh
set -eu

openwrt_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$openwrt_dir/ui"
flutter pub get
flutter build web --release --wasm --base-href / --no-web-resources-cdn

python3 - "$openwrt_dir" <<'PY'
import re
import hashlib
import gzip
import json
import shutil
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
resources = root / 'iping/src/webui'
with tempfile.TemporaryDirectory(prefix='.iping-web-', dir=resources) as temporary:
    staged = Path(temporary) / 'dist'
    shutil.copytree(root / 'ui/build/web', staged)
    (staged / '.keep').touch()
    font_manifest = staged / 'assets/FontManifest.json'
    font_definitions = json.loads(font_manifest.read_text())
    # Shared styles use native font names; dependency bundles prefix those names.
    for font in font_definitions:
        font['family'] = font['family'].removeprefix('packages/fl_clash/')
    font_manifest.write_text(json.dumps(font_definitions, separators=(',', ':')))
    font_families = {font['family'] for font in font_definitions}
    if not {'Twemoji', 'JetBrainsMono'}.issubset(font_families):
        raise RuntimeError('The Web app must register the shared UI font names')
    bootstrap = (staged / 'flutter_bootstrap.js').read_text()
    revision = re.search(r'"engineRevision":"([0-9a-f]{40})"', bootstrap)
    if revision is None:
        raise RuntimeError('Cannot find the Flutter engine revision in the Web build')
    engine_revision = revision.group(1)
    fonts = json.loads((staged / 'fallback-fonts/manifest.json').read_text())
    if fonts['engineRevision'] != engine_revision:
        raise RuntimeError('Refresh the bundled fallback fonts for this Flutter engine')
    for name, digest in fonts['files'].items():
        if hashlib.sha256((staged / 'fallback-fonts' / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Bundled fallback font checksum mismatch: ' + name)
    (staged / 'renderer-version').write_text(engine_revision)
    shutil.rmtree(staged / 'assets/packages/fl_clash/assets/data', ignore_errors=True)
    for file in (staged / 'canvaskit').rglob('*'):
        if file.is_file() and (file.name.endswith('.symbols') or file.name.startswith('wimp')):
            file.unlink()
    fingerprint = hashlib.sha256()
    for file in sorted(staged.rglob('*')):
        if file.is_file():
            fingerprint.update(file.relative_to(staged).as_posix().encode())
            fingerprint.update(file.read_bytes())
    ui_revision = fingerprint.hexdigest()[:16]
    for name in ['index.html', 'flutter_bootstrap.js']:
        file = staged / name
        file.write_text(file.read_text()
                        .replace('__IPING_UI_REVISION__', ui_revision)
                        .replace('__IPING_ENGINE_REVISION__', engine_revision))
    (staged / 'ui-version').write_text(ui_revision)
    etags = {}
    for file in sorted(staged.rglob('*')):
        if not file.is_file():
            continue
        data = file.read_bytes()
        etags[file.relative_to(staged).as_posix()] = hashlib.sha256(data).hexdigest()
        if file.suffix in {'.js', '.mjs', '.wasm', '.json', '.ttf', '.otf', '.svg', '.html', '.css'}:
            compressed = gzip.compress(data, compresslevel=9, mtime=0)
            if len(compressed) < len(data):
                encoded = file.with_name(file.name + '.gz')
                encoded.write_bytes(compressed)
                etags[encoded.relative_to(staged).as_posix()] = hashlib.sha256(compressed).hexdigest()
                if len(data) > 1024 and file.name != 'index.html':
                    file.unlink()
    (staged / 'asset-etags.json').write_text(json.dumps(etags, sort_keys=True))
    output = resources / 'dist'
    previous = Path(temporary) / 'previous'
    if output.exists():
        output.rename(previous)
    try:
        staged.rename(output)
    except OSError:
        if previous.exists():
            previous.rename(output)
        raise
PY
