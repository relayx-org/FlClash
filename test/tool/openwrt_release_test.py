import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

script = Path(__file__).resolve().parents[2] / 'tool/ci/openwrt_release.py'
spec = importlib.util.spec_from_file_location('openwrt_release', script)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class OpenWrtReleaseTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.pubspec = self.root / 'pubspec.yaml'
        self.pubspec.write_text('name: test\nversion: 1.2.3+42\n')
        self.feed = self.root / 'feed'
        for name, version in [('iping', '0.1.0'), ('iping-mihomo', '1.19.32')]:
            package = self.feed / name
            package.mkdir(parents=True)
            (package / 'Makefile').write_text(f'PKG_NAME:={name}\nPKG_VERSION:={version}\nPKG_RELEASE:=1\n')
        (self.feed / 'ui').mkdir()
        (self.feed / 'ui/pubspec.yaml').write_text('name: web\nversion: 0.1.0+3\n')
        self.packages = self.root / 'packages'
        self.packages.mkdir()

    def test_release_tag_and_build_stamp(self):
        release.prepare(self.feed, self.pubspec, 'v1.2.3-pre.2')
        self.assertEqual(release.package_version(self.feed, 'iping'), '1.2.3-r42')
        self.assertIn('version: 1.2.3+42', (self.feed / 'ui/pubspec.yaml').read_text())
        self.assertEqual(release.package_version(self.feed, 'iping-mihomo'), '1.19.32-r1')
        with self.assertRaises(ValueError):
            release.prepare(self.feed, self.pubspec, 'v1.2.4')

    def test_ipk_and_apk_bundles_keep_the_matching_pair_and_checksums(self):
        for branch, arch, suffix in [('openwrt-24.10', 'x86_64', 'ipk'), ('openwrt-25.12', 'aarch64_cortex-a53', 'apk')]:
            with self.subTest(branch=branch):
                release.prepare(self.feed, self.pubspec)
                names = []
                for name in ['iping-mihomo', 'iping']:
                    version = release.package_version(self.feed, name)
                    filename = f'{name}_{version}_{arch}.ipk' if suffix == 'ipk' else f'{name}-{version}.apk'
                    (self.packages / filename).write_bytes(name.encode())
                    names.append(filename)
                (self.packages / 'luci-app-iping_0.1.0_all.ipk').write_bytes(b'old')
                archive = release.bundle(self.feed, self.packages, self.root / 'dist', self.pubspec, branch, arch)
                self.assertEqual(archive.name, f'iPing-1.2.3-{branch}-{arch}.zip')
                with zipfile.ZipFile(archive) as bundle:
                    self.assertEqual(set(bundle.namelist()), {*names, 'SHA256SUMS', 'INSTALL.txt'})
                    checksums = bundle.read('SHA256SUMS').decode()
                    for name in names:
                        self.assertIn(hashlib.sha256(bundle.read(name)).hexdigest() + '  ' + name, checksums)
                    self.assertIn(branch, bundle.read('INSTALL.txt').decode())

    def test_a_missing_or_stale_package_cannot_create_a_release_bundle(self):
        release.prepare(self.feed, self.pubspec)
        (self.packages / 'iping_0.1.0-r3_x86_64.ipk').write_bytes(b'old')
        (self.packages / 'iping-mihomo_1.19.32-r1_x86_64.ipk').write_bytes(b'core')
        with self.assertRaises(ValueError):
            release.bundle(self.feed, self.packages, self.root / 'dist', self.pubspec, 'openwrt-24.10', 'x86_64')
        self.assertFalse((self.root / 'dist').exists())


if __name__ == '__main__':
    unittest.main()
