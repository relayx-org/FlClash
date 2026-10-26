import hashlib
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

script = Path(__file__).resolve().parents[2] / 'tool/ci/storage.py'
spec = importlib.util.spec_from_file_location('storage', script)
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)


class StorageTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.store = storage.BuildStorage('12345', 'a' * 40, '1.2.3+42')
        self.objects = self.root / 'objects'
        self.objects.mkdir()
        def aws(action, source, destination, *options, **kwargs):
            def path(value):
                return self.objects / value.removeprefix('s3://iping/releases/builds/') if value.startswith('s3://') else Path(value)
            origin, target = path(source), path(destination)
            if '--recursive' in options:
                shutil.copytree(origin, target, dirs_exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(origin, target)
        self.store.aws = aws

    def test_roundtrip_requires_complete_receipts_and_verifies_every_download(self):
        source = self.root / 'source'
        source.mkdir()
        (source / 'iPing.zip').write_bytes(b'valid binary')
        (source / '.keep').write_bytes(b'')
        self.store.put('linux-amd64', source)
        (self.root / 'destination').mkdir()
        (self.root / 'destination/.keep').write_bytes(b'')
        self.store.get('linux-amd64', self.root / 'destination')
        self.assertEqual((self.root / 'destination/iPing.zip').read_bytes(), b'valid binary')
        (self.objects / '12345/linux-amd64/files/iPing.zip').write_bytes(b'corrupt')
        with self.assertRaises(ValueError):
            self.store.get('linux-amd64', self.root / 'corrupt')
        self.assertFalse((self.root / 'corrupt/iPing.zip').exists())

    def test_different_source_and_unsafe_receipts_are_rejected(self):
        info = {'sha256': hashlib.sha256(b'data').hexdigest(), 'size': 4}
        receipt = {'sha': 'a' * 40, 'version': '1.2.3+42', 'stable': True, 'files': {'binary': info}}
        for field, value in [('sha', 'b' * 40), ('version', '1.2.4+42'), ('stable', False)]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                storage.validate_receipt({**receipt, field: value}, self.store.sha, self.store.version)
        for name in ['../secret', '/etc/passwd', 'C:/file', r'a\b', 'x/../file']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                storage.validate_receipt({**receipt, 'files': {name: info}}, self.store.sha, self.store.version)
        with self.assertRaises(ValueError):
            self.store.prefix('../other-run')

    def test_partial_resume_reuses_completed_groups_and_builds_only_missing_targets(self):
        source = self.root / 'source'
        source.mkdir()
        (source / 'file').write_bytes(b'data')
        for group in storage.NATIVE_GROUPS:
            if group != 'windows-amd64':
                self.store.put(group, source)
        self.store.put('web', source)
        self.store.put('agent-x86_64', source)
        resumed = storage.BuildStorage('67890', self.store.sha, self.store.version)
        resumed.aws = self.store.aws
        matrix, web, agents = resumed.plan(self.store)
        self.assertEqual([row['platform'] for row in matrix['include']], ['windows'])
        self.assertTrue(web)
        self.assertEqual([row['arch'] for row in agents['include']], ['aarch64', 'armv7', 'mips', 'mipsel'])
        resumed.get('linux-amd64', self.root / 'resumed')
        self.assertEqual((self.root / 'resumed/file').read_bytes(), b'data')

    def test_failed_upload_never_publishes_a_receipt(self):
        source = self.root / 'source'
        source.mkdir()
        (source / 'file').write_bytes(b'data')
        calls = []
        def aws(*args):
            calls.append(args)
            raise OSError('connection interrupted')
        self.store.aws = aws
        with self.assertRaises(OSError):
            self.store.put('web', source)
        self.assertEqual(len(calls), 1)
        self.assertNotIn('receipt.json', str(calls[0]))

    def test_local_cache_verifies_bytes_and_follows_the_current_receipt(self):
        source = self.root / 'source'
        source.mkdir()
        (source / 'file').write_bytes(b'first build')
        self.store.put('linux-amd64', source)
        cache = self.root / 'cache'
        calls = []
        aws = self.store.aws
        def counted_aws(*args, **kwargs):
            calls.append(args)
            return aws(*args, **kwargs)
        self.store.aws = counted_aws
        self.store.get('linux-amd64', self.root / 'first', cache)
        calls.clear()
        self.store.get('linux-amd64', self.root / 'second', cache)
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0][1].endswith('receipt.json'))
        self.assertEqual((self.root / 'second/file').read_bytes(), b'first build')
        next(cache.glob('*/file')).write_bytes(b'bad cache')
        calls.clear()
        self.store.get('linux-amd64', self.root / 'repaired', cache)
        self.assertEqual(len(calls), 2)
        self.assertEqual((self.root / 'repaired/file').read_bytes(), b'first build')
        (source / 'file').write_bytes(b'new build')
        self.store.put('linux-amd64', source)
        self.store.get('linux-amd64', self.root / 'changed', cache)
        self.assertEqual((self.root / 'changed/file').read_bytes(), b'new build')


if __name__ == '__main__':
    unittest.main()
