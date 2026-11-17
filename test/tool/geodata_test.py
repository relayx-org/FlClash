import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

script = Path(__file__).resolve().parents[2] / 'tool/ci/geodata.py'
spec = importlib.util.spec_from_file_location('geodata', script)
geodata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(geodata)


class GeodataTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.payloads = {name: (name + '-database').encode() for name in geodata.FILES.values()}
        self.release = {'id': 42, 'published_at': '2026-11-17', 'assets': [
            {'name': name, 'size': len(data), 'digest': 'sha256:' + hashlib.sha256(data).hexdigest(),
             'browser_download_url': 'https://example.com/' + name}
            for name, data in self.payloads.items()]}

    def download(self, url, output):
        if url == geodata.RELEASE_URL:
            output.write_text(json.dumps(self.release))
        else:
            output.write_bytes(self.payloads[url.rsplit('/', 1)[-1]])

    def test_one_verified_snapshot_stages_native_and_compressed_agent_assets(self):
        with patch.object(geodata, 'download', side_effect=self.download) as download:
            geodata.fetch(self.root / 'snapshot')
        self.assertEqual(sum(call.args[0] == geodata.RELEASE_URL for call in download.call_args_list), 1)
        geodata.stage_to(self.root / 'snapshot', self.root / 'native')
        geodata.stage_to(self.root / 'snapshot', self.root / 'agent', compressed=True)
        for name, upstream in geodata.FILES.items():
            self.assertEqual((self.root / 'native' / name).read_bytes(), self.payloads[upstream])
            self.assertEqual(gzip.decompress((self.root / 'agent' / (name + '.gz')).read_bytes()), self.payloads[upstream])
        self.assertEqual((self.root / 'native/manifest.json').read_bytes(), (self.root / 'agent/manifest.json').read_bytes())

    def test_incomplete_download_never_replaces_the_previous_snapshot(self):
        with patch.object(geodata, 'download', side_effect=self.download):
            geodata.fetch(self.root / 'snapshot')
            previous = (self.root / 'snapshot/GEOIP.metadb').read_bytes()
            self.payloads['geoip.metadb'] = b'incomplete'
            with self.assertRaises(ValueError):
                geodata.fetch(self.root / 'snapshot')
        self.assertEqual((self.root / 'snapshot/GEOIP.metadb').read_bytes(), previous)

    def test_corrupt_snapshot_cannot_enter_a_package(self):
        with patch.object(geodata, 'download', side_effect=self.download):
            geodata.fetch(self.root / 'snapshot')
        (self.root / 'snapshot/GEOIP.metadb').write_bytes(b'bad')
        with self.assertRaises(ValueError):
            geodata.stage_to(self.root / 'snapshot', self.root / 'package')
        self.assertFalse((self.root / 'package').exists())


if __name__ == '__main__':
    unittest.main()
