import argparse
import fnmatch
import json
import os
import re
import subprocess


NATIVE_ARTIFACTS = {
    'artifact-android-multi', 'artifact-ios-arm64', 'artifact-linux-amd64',
    'artifact-windows-amd64', 'artifact-macos-arm64', 'artifact-macos-amd64',
    'openwrt-web',
}
TOOLING_PATHS = [
    '.github/*', '.agents/*', 'test/tool/*', 'tool/ci/*',
    'tool/package_ios.dart', 'tool/sign_macos.sh', 'tool/update_manifest.dart',
    'openwrt/iping/files/iping-update', 'openwrt/README.md',
    'openwrt/iping/Makefile', 'openwrt/iping-mihomo/Makefile',
]


def validate_reuse(run, artifacts, changed_paths, tag):
    if (run['path'] != '.github/workflows/build.yaml' or run['name'] != 'Release ' + tag
            or run['event'] != 'workflow_dispatch' or run['head_branch'] != 'main'):
        raise ValueError('Only a manually dispatched main release build can be reused')
    if any(not any(fnmatch.fnmatch(name, pattern) for pattern in TOOLING_PATHS)
           for name in changed_paths):
        raise ValueError('The previous run has different application source')
    available = {a['name'] for a in artifacts if not a['expired']}
    if not NATIVE_ARTIFACTS <= available:
        raise ValueError('The previous run does not contain every native platform and Web artifact')
    return sorted(available & NATIVE_ARTIFACTS)


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True, type=int)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--tag', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-f]{40}', args.sha) or args.run <= 0:
        raise ValueError('Invalid release commit or previous run ID')
    base = f'repos/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{args.run}'
    previous = json.loads(run('gh', 'api', base))
    artifacts = json.loads(run('gh', 'api', base + '/artifacts?per_page=100'))['artifacts']
    for sha in (args.sha, previous['head_sha']):
        run('git', 'fetch', '--no-tags', '--depth=1', 'origin', sha)
    changed = run('git', 'diff', '--name-only', args.sha, previous['head_sha']).splitlines()
    validate_reuse(previous, artifacts, changed, args.tag)
    print('Reusing validated native and Web artifacts; rebuilding the binary installer')


if __name__ == '__main__':
    main()
