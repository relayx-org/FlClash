import argparse
import hashlib
from pathlib import Path
import re
import zipfile


def release_version(pubspec, tag=''):
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', pubspec.read_text(), re.M)
    if not match or int(match[2]) <= 0:
        raise ValueError('Expected pubspec version MAJOR.MINOR.PATCH+BUILD')
    version, build = match.groups()
    if tag and not re.fullmatch(r'v' + re.escape(version) + r'(?:-pre\.\d+)?', tag):
        raise ValueError('Release tag does not match pubspec version')
    return version, build


def prepare(feed, pubspec, tag=''):
    version, build = release_version(pubspec, tag)
    path = feed / 'iping/Makefile'
    source = path.read_text()
    for key, value in [('PKG_VERSION', version), ('PKG_RELEASE', build)]:
        source, count = re.subn(r'^' + key + r':=.*$', key + ':=' + value, source, flags=re.M)
        if count != 1:
            raise ValueError('Expected exactly one ' + key)
    path.write_text(source)
    web = feed / 'ui/pubspec.yaml'
    if web.exists():
        source, count = re.subn(r'^version:.*$', 'version: ' + version + '+' + build, web.read_text(), flags=re.M)
        if count != 1:
            raise ValueError('Expected exactly one Web package version')
        web.write_text(source)


def package_version(feed, name):
    source = (feed / name / 'Makefile').read_text()
    values = []
    for key in ['PKG_VERSION', 'PKG_RELEASE']:
        match = re.search(r'^' + key + r':=([\d.]+)\s*$', source, re.M)
        if not match:
            raise ValueError('Missing package version in ' + name)
        values.append(match[1])
    return '-r'.join(values)


def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def bundle(feed, packages, output, pubspec, branch, arch, tag=''):
    version, build = release_version(pubspec, tag)
    if branch not in ['openwrt-24.10', 'openwrt-25.12'] or not re.fullmatch(r'[a-zA-Z0-9_-]+', arch):
        raise ValueError('Invalid OpenWrt branch or architecture')
    if package_version(feed, 'iping') != version + '-r' + build:
        raise ValueError('Agent package version was not prepared for this release')
    extension = '.ipk' if branch == 'openwrt-24.10' else '.apk'
    selected = []
    for name in ['iping-mihomo', 'iping']:
        package = package_version(feed, name)
        filename = f'{name}_{package}_{arch}.ipk' if extension == '.ipk' else f'{name}-{package}.apk'
        path = packages / filename
        if not path.is_file() or path.is_symlink() or path.stat().st_size == 0:
            raise ValueError('Missing or empty package: ' + filename)
        selected.append(path)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f'iPing-{version}-{branch}-{arch}.zip'
    checksums = ''.join(f'{checksum(path)}  {path.name}\n' for path in selected)
    install = 'opkg install' if extension == '.ipk' else 'apk add --allow-untrusted'
    instructions = f'iPing {version}+{build}\n{branch} / {arch}\n\n' + install + ' ' + ' '.join('./' + path.name for path in selected) + '\n'
    temporary = archive.with_suffix('.zip.tmp')
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_STORED) as package:
            for path in selected:
                package.write(path, path.name)
            package.writestr('SHA256SUMS', checksums)
            package.writestr('INSTALL.txt', instructions)
        temporary.replace(archive)
    finally:
        temporary.unlink(missing_ok=True)
    return archive


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'bundle'])
    parser.add_argument('--feed', type=Path, default=Path('openwrt'))
    parser.add_argument('--pubspec', type=Path, default=Path('pubspec.yaml'))
    parser.add_argument('--release-tag', default='')
    parser.add_argument('--packages', type=Path)
    parser.add_argument('--output', type=Path, default=Path('dist'))
    parser.add_argument('--branch')
    parser.add_argument('--arch')
    args = parser.parse_args()
    if args.action == 'prepare':
        prepare(args.feed, args.pubspec, args.release_tag)
    else:
        if args.packages is None or args.branch is None or args.arch is None:
            parser.error('bundle requires --packages, --branch and --arch')
        print(bundle(args.feed, args.packages, args.output, args.pubspec, args.branch, args.arch, args.release_tag))


if __name__ == '__main__':
    main()
