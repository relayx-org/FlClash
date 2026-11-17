import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

RELEASE_URL = 'https://api.github.com/repos/MetaCubeX/meta-rules-dat/releases/tags/latest'
FILES = {
    'GEOIP.metadb': 'geoip.metadb',
    'GEOIP.dat': 'geoip.dat',
    'GEOSITE.dat': 'geosite.dat',
    'ASN.mmdb': 'GeoLite2-ASN.mmdb',
}


def checksum(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def download(url, output):
    subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                    '--retry', '3', '--retry-all-errors', '--connect-timeout', '15',
                    '--max-time', '300', '--proto', '=https', '--proto-redir', '=https',
                    '--output', str(output), url], check=True)


def verify(source):
    manifest = json.loads((source / 'manifest.json').read_text())
    if set(manifest['files']) != set(FILES):
        raise ValueError('Incomplete bundled geodata')
    for name, metadata in manifest['files'].items():
        if (not re.fullmatch(r'[0-9a-f]{64}', metadata['sha256'])
                or not isinstance(metadata['size'], int) or metadata['size'] <= 0
                or (source / name).stat().st_size != metadata['size']
                or checksum(source / name) != metadata['sha256']):
            raise ValueError('Bundled geodata failed verification: ' + name)
    return manifest


def fetch(output):
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='iping-geodata-', dir=output.parent) as temporary:
        stage = Path(temporary)
        download(RELEASE_URL, stage / 'release.json')
        release = json.loads((stage / 'release.json').read_text())
        assets = {asset['name']: asset for asset in release['assets']}
        manifest = {'release': release['id'], 'publishedAt': release['published_at'], 'files': {}}
        for name, upstream in FILES.items():
            asset = assets[upstream]
            digest = asset.get('digest', '').removeprefix('sha256:')
            if not re.fullmatch(r'[0-9a-f]{64}', digest):
                raise ValueError('Missing upstream geodata checksum: ' + upstream)
            download(asset['browser_download_url'], stage / name)
            manifest['files'][name] = {'sha256': digest, 'size': asset['size']}
        (stage / 'manifest.json').write_text(json.dumps(manifest, sort_keys=True) + '\n')
        verify(stage)
        stage_to(stage, output)


def stage_to(source, output, compressed=False):
    verify(source)
    output.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        target = output / (name + '.gz' if compressed else name)
        if compressed:
            with target.open('wb') as destination, gzip.GzipFile(fileobj=destination, mode='wb', mtime=0) as encoded:
                with (source / name).open('rb') as data:
                    shutil.copyfileobj(data, encoded)
        else:
            shutil.copyfile(source / name, target)
    shutil.copyfile(source / 'manifest.json', output / 'manifest.json')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['fetch', 'stage', 'verify'])
    parser.add_argument('--source', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--compressed', action='store_true')
    args = parser.parse_args()
    if args.action == 'fetch':
        if args.output is None:
            parser.error('fetch requires --output')
        fetch(args.output)
    else:
        if args.source is None:
            parser.error('stage/verify require --source')
        if args.action == 'verify':
            verify(args.source)
        else:
            if args.output is None:
                parser.error('stage requires --output')
            stage_to(args.source, args.output, args.compressed)


if __name__ == '__main__':
    main()
