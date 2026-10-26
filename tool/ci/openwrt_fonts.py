import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess


def refresh(sdk, output):
    source = sdk / 'bin/cache/flutter_web_sdk/lib/_engine/engine/font_fallback_data.dart'
    paths = sorted(set(re.findall(r"'(notosanssc/[^']+\.woff2)'", source.read_text())))
    if not paths:
        raise ValueError('Cannot find Noto Sans SC fallback fonts in this Flutter SDK')

    def download(name):
        file = output / name
        file.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            'curl', '-fsSL', '--retry', '2', '--max-time', '30',
            'https://fonts.gstatic.com/s/' + name, '-o', str(file),
        ], check=True)
        return name, hashlib.sha256(file.read_bytes()).hexdigest()

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        files = dict(pool.map(download, paths))
    manifest = {
        'engineRevision': (sdk / 'bin/internal/engine.version').read_text().strip(),
        'files': files,
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter-sdk', type=Path, required=True)
    args = parser.parse_args()
    refresh(args.flutter_sdk, Path(__file__).resolve().parents[2] / 'openwrt/ui/web/fallback-fonts')
