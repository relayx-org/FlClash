import importlib.util
from pathlib import Path
import sys
import unittest


directory = Path(__file__).resolve().parents[2] / 'tool/ci'
sys.path.insert(0, str(directory))
spec = importlib.util.spec_from_file_location('reuse_release', directory / 'reuse_release.py')
reuse = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reuse)


class ReuseReleaseTests(unittest.TestCase):
    def setUp(self):
        self.run = {'path': '.github/workflows/build.yaml', 'name': 'Release v0.1.1',
                    'event': 'workflow_dispatch', 'head_branch': 'main'}
        self.artifacts = [{'name': name, 'expired': False} for name in reuse.NATIVE_ARTIFACTS]

    def test_reuses_completed_targets_and_builds_only_missing_architectures(self):
        self.artifacts.append({'name': 'artifact-openwrt-openwrt-24.10-x86_64', 'expired': False})
        matrix = reuse.validate_reuse(self.run, self.artifacts, ['tool/ci/cache.sh'], 'v0.1.1')
        self.assertEqual(len(matrix['include']), 19)
        self.assertNotIn({'branch': 'openwrt-24.10', 'arch': 'x86_64'}, matrix['include'])
        self.assertIn({'branch': 'openwrt-25.12', 'arch': 'x86_64'}, matrix['include'])

    def test_rejects_different_application_source_and_untrusted_workflows(self):
        for changed in ['lib/main.dart', 'core/main.go', 'openwrt/iping/src/main.go', 'pubspec.yaml']:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                reuse.validate_reuse(self.run, self.artifacts, [changed], 'v0.1.1')
        for key, value in [('name', 'Release v0.1.0'), ('path', 'other.yaml'),
                           ('event', 'pull_request'), ('head_branch', 'feature')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                reuse.validate_reuse({**self.run, key: value}, self.artifacts, [], 'v0.1.1')

    def test_requires_every_native_artifact_and_ignores_expired_sdk_packages(self):
        self.artifacts[0]['expired'] = True
        with self.assertRaises(ValueError):
            reuse.validate_reuse(self.run, self.artifacts, [], 'v0.1.1')
        self.artifacts[0]['expired'] = False
        self.artifacts.append({'name': 'artifact-openwrt-openwrt-24.10-x86_64', 'expired': True})
        self.assertEqual(len(reuse.validate_reuse(self.run, self.artifacts, [], 'v0.1.1')['include']), 20)


if __name__ == '__main__':
    unittest.main()
