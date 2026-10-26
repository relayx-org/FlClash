import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile

NATIVE_GROUPS = ['android-multi', 'ios-arm64', 'linux-amd64', 'windows-amd64', 'macos-arm64', 'macos-amd64']
AGENT_GROUPS = ['agent-' + arch for arch in ('x86_64', 'aarch64', 'armv7', 'mips', 'mipsel')]


def checksum(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def validate_receipt(receipt, sha, tag):
    if receipt.get('sha') != sha or receipt.get('tag') != tag or not receipt.get('files'):
        raise ValueError('MinIO build receipt does not match the release source')
    for name, metadata in receipt['files'].items():
        path = PurePosixPath(name)
        if (path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name
                or str(path) != name or not path.parts):
            raise ValueError('Unsafe file in MinIO build receipt')
        if not re.fullmatch(r'[0-9a-f]{64}', metadata.get('sha256', '')) or metadata.get('size', 0) <= 0:
            raise ValueError('Invalid file metadata in MinIO build receipt')


class BuildStorage:
    def __init__(self, run, sha, tag):
        if not re.fullmatch(r'[0-9]+', run) or not re.fullmatch(r'[0-9a-f]{40}', sha):
            raise ValueError('Invalid build run or release SHA')
        if not re.fullmatch(r'v\d+\.\d+\.\d+(?:-pre\.\d+)?', tag):
            raise ValueError('Invalid release tag')
        self.root = f's3://iping/releases/builds/{run}/'
        self.sha, self.tag = sha, tag

    def aws(self, *args):
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
                            's3', *args, '--only-show-errors'], env=env, check=True)

    def prefix(self, group):
        if not re.fullmatch(r'[a-z0-9_-]+', group):
            raise ValueError('Invalid MinIO build group')
        return self.root + group + '/'

    def receipt(self, group):
        with tempfile.TemporaryDirectory(prefix='iping-receipt-') as temporary:
            path = Path(temporary) / 'receipt.json'
            self.aws('cp', self.prefix(group) + 'receipt.json', str(path))
            receipt = json.loads(path.read_text())
        validate_receipt(receipt, self.sha, self.tag)
        return receipt

    def put(self, group, source):
        files = {path.relative_to(source).as_posix(): {'sha256': checksum(path), 'size': path.stat().st_size}
                 for path in sorted(source.rglob('*')) if path.is_file() and not path.is_symlink()}
        receipt = {'sha': self.sha, 'tag': self.tag, 'files': files}
        validate_receipt(receipt, self.sha, self.tag)
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
                    raise ValueError('Duplicate build file: ' + name)
                shutil.move(str(path), target)
        print(f'Loaded and verified {group}: {len(receipt["files"])} files from MinIO')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['put', 'get', 'check', 'collect'])
    parser.add_argument('--run', default=os.environ.get('GITHUB_RUN_ID', ''))
    parser.add_argument('--reuse-run', default='')
    parser.add_argument('--sha', default=os.environ.get('RELEASE_SHA', ''))
    parser.add_argument('--tag', default=os.environ.get('RELEASE_TAG', ''))
    parser.add_argument('--group')
    parser.add_argument('--path', type=Path)
    args = parser.parse_args()
    storage = BuildStorage(args.run, args.sha, args.tag)
    if args.action == 'check':
        for group in NATIVE_GROUPS + ['web']:
            storage.receipt(group)
        print('Validated native and Web receipts in MinIO')
    elif args.action == 'collect':
        if args.path is None:
            parser.error('collect requires --path')
        native = BuildStorage(args.reuse_run or args.run, args.sha, args.tag)
        for group in NATIVE_GROUPS:
            native.get(group, args.path)
        for group in AGENT_GROUPS + ['installer']:
            storage.get(group, args.path)
    else:
        if args.group is None or args.path is None:
            parser.error('put/get require --group and --path')
        getattr(storage, args.action)(args.group, args.path)


if __name__ == '__main__':
    main()
