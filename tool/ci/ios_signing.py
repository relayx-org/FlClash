import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone


TEAM_ID = 'XGZ79JAGXJ'
APP_ID = 'my.iping.client'
BUNDLES = {'Runner': APP_ID, 'PacketTunnel': APP_ID + '.PacketTunnel'}
PROFILE_SECRETS = ['IOS_PROVISIONING_PROFILE', 'IOS_TUNNEL_PROVISIONING_PROFILE']
PROFILE_DIRECTORY = Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles'


def run(*args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} {args[1]} failed: {result.stderr.decode(errors="replace")}')
    return result.stdout


def validate_profiles(profiles, now=None):
    now = now or datetime.now(timezone.utc)
    certificates = None
    for bundle_id, profile in zip(BUNDLES.values(), profiles):
        entitlements = profile['Entitlements']
        if (profile['TeamIdentifier'] != [TEAM_ID]
                or entitlements.get('application-identifier') != TEAM_ID + '.' + bundle_id):
            raise ValueError(f'Provisioning profile does not match {bundle_id} and team {TEAM_ID}')
        if profile['ExpirationDate'].replace(tzinfo=timezone.utc) <= now:
            raise ValueError(f'Expired provisioning profile for {bundle_id}')
        if (entitlements.get('get-task-allow')
                or profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')):
            raise ValueError(f'An App Store distribution profile is required for {bundle_id}')
        if ('packet-tunnel-provider' not in entitlements.get('com.apple.developer.networking.networkextension', [])
                or 'group.' + APP_ID not in entitlements.get('com.apple.security.application-groups', [])):
            raise ValueError(f'VPN and App Group capabilities are required for {bundle_id}')
        if not re.fullmatch(r'[0-9a-fA-F-]{36}', profile['UUID']):
            raise ValueError('Invalid provisioning profile UUID')
        fingerprints = {hashlib.sha1(cert).hexdigest().upper() for cert in profile['DeveloperCertificates']}
        certificates = fingerprints if certificates is None else certificates & fingerprints
    if len(profiles) != len(BUNDLES) or not certificates:
        raise ValueError('Both provisioning profiles must use the same signing certificate')
    return certificates


def keychains():
    return shlex.split(run('security', 'list-keychains', '-d', 'user').decode())


def export_options(profiles, identity):
    managed = {profile.get('IsXcodeManaged', False) for profile in profiles}
    if len(managed) != 1:
        raise ValueError('Both profiles must use the same provisioning management style')
    automatic = managed.pop()
    options = {
        'method': 'app-store-connect',
        'destination': 'export',
        'teamID': TEAM_ID,
        'signingStyle': 'automatic' if automatic else 'manual',
        'signingCertificate': identity,
        'manageAppVersionAndBuildNumber': False,
    }
    if not automatic:
        options['provisioningProfiles'] = {
            bundle: profile['UUID'] for bundle, profile in zip(BUNDLES.values(), profiles)
        }
    return options


def verify_signing_key(directory, identity, keychain):
    source, binary = directory / 'signing-check.c', directory / 'signing-check'
    source.write_text('int main(void) { return 0; }\n')
    try:
        run('xcrun', 'clang', str(source), '-o', str(binary))
        print('Checking distribution key access in the temporary keychain', flush=True)
        run('codesign', '--force', '--sign', identity, '--keychain', keychain, str(binary))
        print('Checking distribution key access through the user search list', flush=True)
        run('codesign', '--force', '--sign', identity, str(binary))
    finally:
        source.unlink(missing_ok=True)
        binary.unlink(missing_ok=True)


def activate(directory):
    keychain = str(directory / 'signing.keychain-db')
    if not Path(keychain).is_file():
        raise ValueError('The temporary iOS signing keychain is missing')
    identity = plistlib.loads((directory / 'ExportOptions.plist').read_bytes())['signingCertificate']
    run('security', 'list-keychains', '-d', 'user', '-s', keychain,
        *(path for path in keychains() if path != keychain))
    verify_signing_key(directory, identity, keychain)


def prepare(directory):
    os.umask(0o077)
    profiles = []
    for secret in PROFILE_SECRETS:
        path = directory / (secret + '.mobileprovision')
        path.write_bytes(base64.b64decode(os.environ[secret], validate=True))
        profiles.append(plistlib.loads(run('security', 'cms', '-D', '-i', str(path))))
    certificates = validate_profiles(profiles)
    certificate = directory / 'certificate.p12'
    certificate.write_bytes(base64.b64decode(os.environ['IOS_CERTIFICATE'], validate=True))
    keychain = str(directory / 'signing.keychain-db')
    password = base64.b64encode(os.urandom(32)).decode()
    try:
        run('security', 'create-keychain', '-p', password, keychain)
        run('security', 'set-keychain-settings', '-lut', '21600', keychain)
        run('security', 'unlock-keychain', '-p', password, keychain)
        run('security', 'import', str(certificate), '-P', os.environ['IOS_CERTIFICATE_PASSWORD'],
            '-A', '-t', 'cert', '-f', 'pkcs12', '-k', keychain)
        run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-k', password, keychain)
    finally:
        certificate.unlink(missing_ok=True)
    identities = run('security', 'find-identity', '-v', '-p', 'codesigning', keychain).decode()
    matching = certificates & set(re.findall(r'\b[0-9A-F]{40}\b', identities))
    if not matching:
        raise ValueError('The iOS certificate does not match both provisioning profiles')
    identity = sorted(matching)[0]
    PROFILE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    installed = []
    state = directory / 'profiles.json'
    state.write_text(json.dumps(installed))
    for secret, profile in zip(PROFILE_SECRETS, profiles):
        destination = PROFILE_DIRECTORY / (profile['UUID'] + '.mobileprovision')
        source = directory / (secret + '.mobileprovision')
        if destination.exists():
            if destination.read_bytes() != source.read_bytes():
                raise ValueError('A different provisioning profile already uses this UUID')
        else:
            installed.append(str(destination))
            state.write_text(json.dumps(installed))
            shutil.copyfile(source, destination)
    options = directory / 'ExportOptions.plist'
    options.write_bytes(plistlib.dumps(export_options(profiles, identity)))
    activate(directory)
    with open(os.environ['GITHUB_ENV'], 'a') as environment:
        environment.write(f'EXPORT_OPTIONS_PLIST={options}\n')
    print('Prepared iOS distribution signing for Runner and PacketTunnel')


def cleanup(directory):
    keychain = str(directory / 'signing.keychain-db')
    if Path(keychain).exists():
        run('security', 'list-keychains', '-d', 'user', '-s',
            *(path for path in keychains() if path != keychain))
        run('security', 'delete-keychain', keychain)
    state = directory / 'profiles.json'
    if state.exists():
        for name in json.loads(state.read_text()):
            path = Path(name)
            if path.parent != PROFILE_DIRECTORY or not re.fullmatch(r'[0-9a-fA-F-]{36}\.mobileprovision', path.name):
                raise ValueError('Invalid installed profile path')
            path.unlink(missing_ok=True)
    shutil.rmtree(directory)


if __name__ == '__main__':
    directory = Path(sys.argv[2]).resolve()
    if (directory.parent != Path(os.environ['RUNNER_TEMP']).resolve()
            or not directory.name.startswith('iping-ios-signing-')):
        raise ValueError('Use an isolated iPing signing directory inside RUNNER_TEMP')
    {'prepare': prepare, 'activate': activate, 'cleanup': cleanup}[sys.argv[1]](directory)
