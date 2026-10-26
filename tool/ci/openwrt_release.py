import argparse
import gzip
import hashlib
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile

MIHOMO_VERSION = '1.19.32'
ARCHITECTURES = {
    'x86_64': ('amd64', 'amd64-compatible', 'ba3ce607747a07f948fc35780e108a4a7c7f552a38b9bd4d115f313ebcb89c20'),
    'aarch64': ('arm64', 'arm64', '9dd862e28b46ff7d775f169cceebc28deccaa0a9e804237d421cd2571e0caba0'),
    'armv7': ('arm', 'armv7', 'f622cbe903ba1a11d30e9071d1c5373929c675b854856ff3e7f977255a25bb66'),
    'mips': ('mips', 'mips-softfloat', '8b6c0e437ca388d7849db5343ef24304a9b4cf63f12e926eb75d4c7251cd6ab1'),
    'mipsel': ('mipsle', 'mipsle-softfloat', '69b10ecd1db5244ab2bf1fac3c629a2e0f9b19f84728fe51b043a9767832d38c'),
}
PAYLOAD = {'agent', 'mihomo', 'update', 'iping.init', 'iping.conf', 'iping.upgrade', 'version', 'LICENSE'}


def release_version(pubspec, tag=''):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', pubspec.read_text(), re.M)
    if not match or int(match[2]) <= 0:
        raise ValueError('Expected pubspec version MAJOR.MINOR.PATCH+BUILD')
    version, build = match.groups()
    if tag and not re.fullmatch(r'v' + re.escape(version) + r'(?:-pre\.\d+)?', tag):
        raise ValueError('Release tag does not match pubspec version')
    return version, build


def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def validate_binary(path, arch):
    expected = {'x86_64': (2, 1, 62), 'aarch64': (2, 1, 183),
                'armv7': (1, 1, 40), 'mips': (1, 2, 8), 'mipsel': (1, 1, 8)}[arch]
    with path.open('rb') as binary:
        header = binary.read(64)
        if header[:4] != b'\x7fELF' or tuple(header[4:6]) != expected[:2]:
            raise ValueError('Wrong binary architecture: ' + str(path))
        endian = '<' if header[5] == 1 else '>'
        if struct.unpack_from(endian + 'H', header, 18)[0] != expected[2]:
            raise ValueError('Wrong ELF machine: ' + str(path))
        offset = struct.unpack_from(endian + ('Q' if header[4] == 2 else 'I'), header, 32 if header[4] == 2 else 28)[0]
        entry_size, count = struct.unpack_from(endian + 'HH', header, 54 if header[4] == 2 else 42)
        if entry_size < 4 or count == 0:
            raise ValueError('Missing ELF program headers')
        for index in range(count):
            binary.seek(offset + index * entry_size)
            kind = struct.unpack(endian + 'I', binary.read(4))[0]
            if kind in (2, 3):
                raise ValueError('The release requires static binaries: ' + str(path))


def fetch_core(arch, cache):
    _, variant, digest = ARCHITECTURES[arch]
    filename = f'mihomo-linux-{variant}-v{MIHOMO_VERSION}.gz'
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / filename
    if not archive.is_file() or checksum(archive) != digest:
        with tempfile.TemporaryDirectory(dir=cache) as temporary:
            download = Path(temporary) / filename
            subprocess.run(['curl', '--fail', '--location', '--retry', '3', '--retry-all-errors',
                            '--max-time', '300', '--output', str(download),
                            f'https://github.com/MetaCubeX/mihomo/releases/download/v{MIHOMO_VERSION}/{filename}'], check=True)
            if checksum(download) != digest:
                raise ValueError('Mihomo release checksum mismatch')
            download.replace(archive)
    return archive


def bundle(feed, binaries, output, pubspec, arch, tag=''):
    version, build = release_version(pubspec, tag)
    if arch not in ARCHITECTURES:
        raise ValueError('Unsupported OpenWrt architecture')
    for name in ('agent', 'mihomo'):
        validate_binary(binaries / name, arch)
    files = {name: binaries / name for name in ('agent', 'mihomo')}
    files.update({name: feed / 'iping/files' / source for name, source in (
        ('update', 'iping-update'), ('iping.init', 'iping.init'),
        ('iping.conf', 'iping.conf'), ('iping.upgrade', 'iping.upgrade'),
    )})
    files['LICENSE'] = feed.parent / 'LICENSE'
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'iPing-{version}-openwrt-{arch}.zip'
    with tempfile.TemporaryDirectory(dir=output) as temporary:
        staged = Path(temporary)
        for name, source in files.items():
            shutil.copyfile(source, staged / name)
        (staged / 'version').write_text(version + '+' + build + '\n')
        (staged / 'SHA256SUMS').write_text(''.join(
            f'{checksum(staged / name)}  {name}\n' for name in sorted(PAYLOAD)))
        pending = staged / 'bundle.zip'
        with zipfile.ZipFile(pending, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1) as package:
            for name in sorted(PAYLOAD | {'SHA256SUMS'}):
                package.write(staged / name, name)
        pending.replace(archive)
    return archive


def build(feed, output, cache, pubspec, arch, tag=''):
    release_version(pubspec, tag)
    goarch, _, _ = ARCHITECTURES[arch]
    env = {**os.environ, 'CGO_ENABLED': '0', 'GOOS': 'linux', 'GOARCH': goarch,
           'GOAMD64': 'v1', 'GOARM64': 'v8.0', 'GOARM': '7', 'GOMIPS': 'softfloat'}
    with tempfile.TemporaryDirectory(prefix='iping-binaries-') as temporary:
        binaries = Path(temporary)
        subprocess.run(['go', 'build', '-trimpath', '-buildvcs=false', '-ldflags=-s -w -buildid=',
                        '-o', str(binaries / 'agent'), '.'], cwd=feed / 'iping/src', env=env, check=True)
        with gzip.open(fetch_core(arch, cache), 'rb') as source, (binaries / 'mihomo').open('wb') as destination:
            shutil.copyfileobj(source, destination)
        return bundle(feed, binaries, output, pubspec, arch, tag)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['build', 'prepare'])
    parser.add_argument('--feed', type=Path, default=Path('openwrt'))
    parser.add_argument('--pubspec', type=Path, default=Path('pubspec.yaml'))
    parser.add_argument('--release-tag', default='')
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/iping/mihomo')
    parser.add_argument('--arch', choices=ARCHITECTURES)
    args = parser.parse_args()
    if args.action == 'prepare':
        version, number = release_version(args.pubspec, args.release_tag)
        web = args.feed / 'ui/pubspec.yaml'
        source, count = re.subn(r'^version:.*$', 'version: ' + version + '+' + number, web.read_text(), flags=re.M)
        if count != 1:
            raise ValueError('Expected exactly one Web package version')
        web.write_text(source)
    else:
        if args.arch is None:
            parser.error('build requires --arch')
        print(build(args.feed.resolve(), args.output.resolve(), args.cache.resolve(), args.pubspec, args.arch, args.release_tag))


if __name__ == '__main__':
    main()
