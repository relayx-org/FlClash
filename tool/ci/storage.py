import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

NATIVE_TARGETS = json.loads(Path(__file__).with_name('native_targets.json').read_text())['include']
NATIVE_GROUPS = [row['platform'] + '-' + row['arch'] for row in NATIVE_TARGETS]
AGENT_GROUPS = ['agent-' + arch for arch in ('x86_64', 'aarch64', 'armv7', 'mips', 'mipsel')]


def checksum(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def validate_receipt(receipt, sha, version, stable=True):
    if receipt.get('sha') != sha or receipt.get('version') != version or receipt.get('stable') != stable or not receipt.get('files'):
        raise ValueError('MinIO build receipt does not match the release source')
    for name, metadata in receipt['files'].items():
        path = PurePosixPath(name)
        if (path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name
                or str(path) != name or not path.parts):
            raise ValueError('Unsafe file in MinIO build receipt')
        if not re.fullmatch(r'[0-9a-f]{64}', metadata.get('sha256', '')) or not isinstance(metadata.get('size'), int) or metadata['size'] < 0:
            raise ValueError('Invalid file metadata in MinIO build receipt')


class BuildStorage:
    def __init__(self, run, sha, version):
        if not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9a-f]{40}', sha):
            raise ValueError('Invalid build run or release SHA')
        if not re.fullmatch(r'\d+\.\d+\.\d+\+[1-9]\d{0,14}', version):
            raise ValueError('Invalid release version')
        self.root = f's3://iping/releases/builds/{run}/'
        self.sha, self.version = sha, version
        self.stable = os.environ.get('IS_STABLE', 'true') == 'true'

    def aws(self, *args, quiet=False):
        for name in ('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY'):
            if not os.environ.get(name):
                raise ValueError('Missing MinIO credential: ' + name)
        with tempfile.TemporaryDirectory(prefix='iping-s3-') as temporary:
            config = Path(temporary) / 'config'
            config.write_text('[default]\nregion = us-east-1\ns3 =\n  addressing_style = path\n  multipart_threshold = 512MB\n')
            env = {**os.environ, 'AWS_CONFIG_FILE': str(config), 'AWS_EC2_METADATA_DISABLED': 'true',
                   'AWS_REQUEST_CHECKSUM_CALCULATION': 'WHEN_REQUIRED',
                   'AWS_RESPONSE_CHECKSUM_VALIDATION': 'WHEN_REQUIRED', 'AWS_PAGER': ''}
            subprocess.run(['aws', '--endpoint-url', os.environ.get('MINIO_ENDPOINT', 'https://minio.long2ice.io'),
                            's3', *args, '--only-show-errors'], env=env, text=True, capture_output=quiet, check=True)

    def prefix(self, group):
        if not re.fullmatch(r'[a-z0-9_-]+', group):
            raise ValueError('Invalid MinIO build group')
        return self.root + group + '/'

    def receipt(self, group, optional=False):
        with tempfile.TemporaryDirectory(prefix='iping-receipt-') as temporary:
            path = Path(temporary) / 'receipt.json'
            try:
                self.aws('cp', self.prefix(group) + 'receipt.json', str(path), quiet=optional)
            except FileNotFoundError:
                if optional:
                    return None
                raise
            except subprocess.CalledProcessError as error:
                if optional and ('404' in (error.stderr or '') or 'NoSuchKey' in (error.stderr or '')):
                    return None
                raise
            receipt = json.loads(path.read_text())
        validate_receipt(receipt, self.sha, self.version, self.stable)
        return receipt

    def reuse(self, previous, group):
        receipt = previous.receipt(group, optional=True)
        if receipt is None:
            return False
        self.aws('cp', previous.prefix(group) + 'files/', self.prefix(group) + 'files/', '--recursive', '--copy-props', 'none')
        self.aws('cp', previous.prefix(group) + 'receipt.json', self.prefix(group) + 'receipt.json')
        print('Reused MinIO group: ' + group)
        return True

    def plan(self, previous=None):
        rows = [row for row in NATIVE_TARGETS
                if previous is None or not self.reuse(previous, row['platform'] + '-' + row['arch'])]
        web = previous is not None and self.reuse(previous, 'web')
        return {'include': rows}, web

    def put(self, group, source):
        files = {path.relative_to(source).as_posix(): {'sha256': checksum(path), 'size': path.stat().st_size}
                 for path in sorted(source.rglob('*')) if path.is_file() and not path.is_symlink()}
        receipt = {'sha': self.sha, 'version': self.version, 'stable': self.stable, 'files': files}
        validate_receipt(receipt, self.sha, self.version, self.stable)
        self.aws('cp', str(source), self.prefix(group) + 'files/', '--recursive', '--no-follow-symlinks')
        with tempfile.TemporaryDirectory(prefix='iping-receipt-') as temporary:
            path = Path(temporary) / 'receipt.json'
            path.write_text(json.dumps(receipt, sort_keys=True) + '\n')
            self.aws('cp', str(path), self.prefix(group) + 'receipt.json')
        print(f'Saved {group}: {len(files)} files to MinIO')

    def get(self, group, destination):
        receipt = self.receipt(group)
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='iping-download-', dir=destination.parent) as temporary:
            stage = Path(temporary)
            self.aws('cp', self.prefix(group) + 'files/', str(stage), '--recursive')
            for name, metadata in receipt['files'].items():
                path = stage / name
                if path.is_symlink() or not path.is_file() or path.stat().st_size != metadata['size'] or checksum(path) != metadata['sha256']:
                    raise ValueError('MinIO build file failed verification: ' + name)
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    if target.is_file() and checksum(target) == metadata['sha256']:
                        continue
                    raise ValueError('Different build files share a path: ' + name)
                shutil.move(str(path), target)
        print(f'Loaded and verified {group}: {len(receipt["files"])} files from MinIO')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['put', 'get', 'check', 'collect', 'plan'])
    parser.add_argument('--run', default=os.environ.get('GITHUB_RUN_ID', ''))
    parser.add_argument('--reuse-run', default='')
    parser.add_argument('--sha', default=os.environ.get('RELEASE_SHA', ''))
    parser.add_argument('--version', default=os.environ.get('RELEASE_VERSION', ''))
    parser.add_argument('--group')
    parser.add_argument('--path', type=Path)
    args = parser.parse_args()
    storage = BuildStorage(args.run, args.sha, args.version)
    if args.action == 'plan':
        previous = BuildStorage(args.reuse_run, args.sha, args.version) if args.reuse_run else None
        matrix, web = storage.plan(previous)
        with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
            output.write('matrix=' + json.dumps(matrix, separators=(',', ':')) + '\nweb=' + str(web).lower() + '\n')
        print(f'{len(matrix["include"])} native build targets remain')
    elif args.action == 'check':
        for group in NATIVE_GROUPS + ['web']:
            storage.receipt(group)
        print('Validated native and Web receipts in MinIO')
    elif args.action == 'collect':
        if args.path is None:
            parser.error('collect requires --path')
        for group in NATIVE_GROUPS:
            storage.get(group, args.path)
        for group in AGENT_GROUPS + ['installer']:
            storage.get(group, args.path)
    else:
        if args.group is None or args.path is None:
            parser.error('put/get require --group and --path')
        getattr(storage, args.action)(args.group, args.path)


if __name__ == '__main__':
    main()
