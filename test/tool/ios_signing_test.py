import copy
from datetime import datetime, timezone
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    'ios_signing', Path(__file__).resolve().parents[2] / 'tool/ci/ios_signing.py')
signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing)


class SigningTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 10, 25, tzinfo=timezone.utc)
        self.profiles = [{
            'UUID': 'da7d6808-3eed-48bd-884d-7ce30b68ac2b',
            'TeamIdentifier': [signing.TEAM_ID],
            'ExpirationDate': datetime(2027, 5, 16),
            'DeveloperCertificates': [b'common certificate'],
            'Entitlements': {
                'application-identifier': signing.TEAM_ID + '.' + bundle,
                'get-task-allow': False,
                'com.apple.developer.networking.networkextension': ['packet-tunnel-provider'],
                'com.apple.security.application-groups': ['group.' + signing.APP_ID],
            },
        } for bundle in signing.BUNDLES.values()]
        self.profiles[1]['UUID'] = 'ea5ee966-9e3d-41b2-b920-2d39ed7a1113'

    def test_matching_distribution_pair(self):
        self.assertEqual(len(signing.validate_profiles(self.profiles, self.now)), 1)

    def test_export_options_handle_both_profile_management_styles(self):
        manual = signing.export_options(self.profiles, 'distribution identity')
        self.assertEqual(manual['signingStyle'], 'manual')
        self.assertEqual(set(manual['provisioningProfiles']), set(signing.BUNDLES.values()))
        for profile in self.profiles:
            profile['IsXcodeManaged'] = True
        automatic = signing.export_options(self.profiles, 'distribution identity')
        self.assertEqual(automatic['signingStyle'], 'automatic')
        self.assertEqual(automatic['signingCertificate'], 'distribution identity')
        self.assertNotIn('provisioningProfiles', automatic)
        self.assertFalse(automatic['manageAppVersionAndBuildNumber'])
        self.profiles[0]['IsXcodeManaged'] = False
        with self.assertRaises(ValueError):
            signing.export_options(self.profiles, 'distribution identity')

    def test_rejects_unusable_profiles(self):
        cases = {
            'gorelay bundle': lambda p: p[0]['Entitlements'].update(
                {'application-identifier': signing.TEAM_ID + '.net.gorelay.gorelayAgent'}),
            'wrong team': lambda p: p[1].update({'TeamIdentifier': ['ANOTHERTEAM']}),
            'expired': lambda p: p[1].update({'ExpirationDate': datetime(2025, 1, 1)}),
            'development': lambda p: p[0]['Entitlements'].update({'get-task-allow': True}),
            'ad hoc': lambda p: p[0].update({'ProvisionedDevices': ['registered device']}),
            'missing tunnel capability': lambda p: p[1]['Entitlements'].pop(
                'com.apple.developer.networking.networkextension'),
            'wrong group': lambda p: p[1]['Entitlements'].update(
                {'com.apple.security.application-groups': ['group.net.gorelay.gorelayAgent']}),
            'different certificate': lambda p: p[1].update({'DeveloperCertificates': [b'other']}),
            'missing extension': lambda p: p.pop(),
        }
        for name, mutate in cases.items():
            with self.subTest(name=name):
                profiles = copy.deepcopy(self.profiles)
                mutate(profiles)
                with self.assertRaises(ValueError):
                    signing.validate_profiles(profiles, self.now)

    def test_activation_prioritizes_its_keychain_and_preserves_other_jobs(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            keychain = str(directory / 'signing.keychain-db')
            Path(keychain).touch()
            (directory / 'ExportOptions.plist').write_bytes(plistlib.dumps({
                'signingCertificate': 'distribution identity',
            }))
            others = ['/tmp/other job.keychain-db', '/Users/runner/login.keychain-db']
            with (patch.object(signing, 'keychains', return_value=[*others, keychain]),
                  patch.object(signing, 'run') as run,
                  patch.object(signing, 'verify_signing_key') as verify):
                signing.activate(directory)
                run.assert_called_once_with('security', 'list-keychains', '-d', 'user', '-s',
                                            keychain, *others)
                verify.assert_called_once_with(directory, 'distribution identity', keychain)


if __name__ == '__main__':
    unittest.main()
