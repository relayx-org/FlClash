import hashlib
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

script = Path(__file__).resolve().parents[2] / 'tool/ci/openwrt_release.py'
spec = importlib.util.spec_from_file_location('openwrt_release', script)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def elf(arch, dynamic=False):
    bits, order, machine = {'x86_64': (2, 1, 62), 'aarch64': (2, 1, 183),
                            'armv7': (1, 1, 40), 'mips': (1, 2, 8), 'mipsel': (1, 1, 8)}[arch]
    endian = '<' if order == 1 else '>'
    data = bytearray(128)
    data[:6] = b'\x7fELF' + bytes((bits, order))
    struct.pack_into(endian + 'H', data, 18, machine)
    struct.pack_into(endian + ('Q' if bits == 2 else 'I'), data, 32 if bits == 2 else 28, 64)
    struct.pack_into(endian + 'HH', data, 54 if bits == 2 else 42, 56 if bits == 2 else 32, 1)
    struct.pack_into(endian + 'I', data, 64, 3 if dynamic else 1)
    return data


class OpenWrtReleaseTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.pubspec = self.root / 'pubspec.yaml'
        self.pubspec.write_text('name: test\nversion: 1.2.3+42\n')
        (self.root / 'LICENSE').write_text('test license')
        self.feed = self.root / 'openwrt'
        files = self.feed / 'iping/files'
        files.mkdir(parents=True)
        for name in ('iping-update', 'iping.init', 'iping.conf', 'iping.upgrade'):
            (files / name).write_text(name)
        self.binaries = self.root / 'binaries'
        self.binaries.mkdir()

    def test_release_version_must_match_the_tag(self):
        self.assertEqual(release.release_version(self.pubspec, 'v1.2.3-pre.2'), ('1.2.3', '42'))
        with self.assertRaises(ValueError):
            release.release_version(self.pubspec, 'v1.2.4')

    def test_binary_bundles_are_independent_of_firmware_and_contain_verified_runtime_files(self):
        for arch in release.ARCHITECTURES:
            with self.subTest(arch=arch):
                for name in ('agent', 'mihomo'):
                    (self.binaries / name).write_bytes(elf(arch))
                archive = release.bundle(self.feed, self.binaries, self.root / 'dist', self.pubspec, arch)
                self.assertEqual(archive.name, f'iPing-1.2.3-openwrt-{arch}.zip')
                with zipfile.ZipFile(archive) as bundle:
                    self.assertEqual(set(bundle.namelist()), release.PAYLOAD | {'SHA256SUMS'})
                    self.assertEqual(bundle.read('version'), b'1.2.3+42\n')
                    checksums = bundle.read('SHA256SUMS').decode()
                    for name in release.PAYLOAD:
                        self.assertIn(hashlib.sha256(bundle.read(name)).hexdigest() + '  ' + name, checksums)

    def test_dynamic_wrong_endian_and_missing_binaries_cannot_be_published(self):
        for arch, binary in [('x86_64', elf('x86_64', dynamic=True)), ('mips', elf('mipsel'))]:
            with self.subTest(arch=arch):
                (self.binaries / 'agent').write_bytes(binary)
                with self.assertRaises(ValueError):
                    release.bundle(self.feed, self.binaries, self.root / 'dist', self.pubspec, arch)
        (self.binaries / 'agent').write_bytes(elf('x86_64'))
        with self.assertRaises(FileNotFoundError):
            release.bundle(self.feed, self.binaries, self.root / 'dist', self.pubspec, 'x86_64')
        self.assertFalse((self.root / 'dist').exists())


if __name__ == '__main__':
    unittest.main()
