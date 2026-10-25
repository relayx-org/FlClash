#!/bin/sh
set -eu

openwrt_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$openwrt_dir/ui"
flutter pub get
flutter build web --release --base-href / --no-web-resources-cdn

python3 - "$openwrt_dir" <<'PY'
import re
import hashlib
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
    bootstrap = (staged / 'flutter_bootstrap.js').read_text()
    revision = re.search(r'"engineRevision":"([0-9a-f]{40})"', bootstrap)
    if revision is None:
        raise RuntimeError('Cannot find the Flutter engine revision in the Web build')
    (staged / 'renderer-version').write_text(revision.group(1))
    fingerprint = hashlib.sha256()
    for name in ['main.dart.js', 'bridge.js', 'flutter_bootstrap.js']:
        fingerprint.update((staged / name).read_bytes())
    ui_revision = fingerprint.hexdigest()[:16]
    for name in ['index.html', 'flutter_bootstrap.js']:
        file = staged / name
        file.write_text(file.read_text().replace('__IPING_UI_REVISION__', ui_revision))
    (staged / 'ui-version').write_text(ui_revision)
    shutil.rmtree(staged / 'assets/packages/fl_clash/assets/data', ignore_errors=True)
    for file in (staged / 'canvaskit').rglob('*'):
        if file.is_file() and (file.name.endswith('.symbols') or file.name.startswith(('skwasm', 'wimp'))):
            file.unlink()
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
