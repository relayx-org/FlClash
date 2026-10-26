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
        self.store = storage.BuildStorage('12345', 'a' * 40, 'v1.2.3')
        self.objects = self.root / 'objects'
        self.objects.mkdir()
        def aws(action, source, destination, *options):
            def path(value):
                return self.objects / value.removeprefix(self.store.root) if value.startswith('s3://') else Path(value)
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
        self.store.put('linux-amd64', source)
        self.store.get('linux-amd64', self.root / 'destination')
        self.assertEqual((self.root / 'destination/iPing.zip').read_bytes(), b'valid binary')
        (self.objects / 'linux-amd64/files/iPing.zip').write_bytes(b'corrupt')
        with self.assertRaises(ValueError):
            self.store.get('linux-amd64', self.root / 'corrupt')
        self.assertFalse((self.root / 'corrupt/iPing.zip').exists())

    def test_different_source_and_unsafe_receipts_are_rejected(self):
        info = {'sha256': hashlib.sha256(b'data').hexdigest(), 'size': 4}
        receipt = {'sha': 'a' * 40, 'tag': 'v1.2.3', 'files': {'binary': info}}
        for field, value in [('sha', 'b' * 40), ('tag', 'v1.2.4')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                storage.validate_receipt({**receipt, field: value}, self.store.sha, self.store.tag)
        for name in ['../secret', '/etc/passwd', 'C:/file', r'a\b', 'x/../file']:
            with self.subTest(name=name), self.assertRaises(ValueError):
                storage.validate_receipt({**receipt, 'files': {name: info}}, self.store.sha, self.store.tag)
        with self.assertRaises(ValueError):
            self.store.prefix('../other-run')

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


if __name__ == '__main__':
    unittest.main()
