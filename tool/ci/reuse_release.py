import argparse
import fnmatch
import json
import os
from pathlib import Path
import re
import subprocess

from openwrt_release import package_matrix


NATIVE_ARTIFACTS = {
    'artifact-android-multi', 'artifact-ios-arm64', 'artifact-linux-amd64',
    'artifact-windows-amd64', 'artifact-macos-arm64', 'artifact-macos-amd64',
    'artifact-openwrt-installer', 'openwrt-web',
}
TOOLING_PATHS = [
    '.github/*', '.agents/*', 'test/tool/*', 'tool/ci/*',
    'tool/package_ios.dart', 'tool/sign_macos.sh',
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
    return package_matrix(available)


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
    matrix = validate_reuse(previous, artifacts, changed, args.tag)
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
        output.write('matrix=' + json.dumps(matrix, separators=(',', ':')) + '\n')
    print(f'Reusing native and Web artifacts; {len(matrix["include"])} OpenWrt targets remain')


if __name__ == '__main__':
    main()
