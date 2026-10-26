import os
from pathlib import Path
import subprocess
import unittest


IMAGE = os.environ.get('IPING_SDK_TEST_IMAGE')
SCRIPT = Path(__file__).resolve().parents[2] / 'tool/ci/openwrt_sdk_cache.sh'


@unittest.skipUnless(IMAGE, 'Set IPING_SDK_TEST_IMAGE to run SDK cache integration checks')
class SdkCacheTests(unittest.TestCase):
    def test_cache_preserves_dependencies_but_never_restores_a_stale_agent(self):
        self.check('''
restore
mkdir -p build_dir/hostpkg/go-1.23 staging_dir/hostpkg/lib/go-cross build_dir/target-test/iping-0.1.0
printf compiler > staging_dir/hostpkg/lib/go-cross/go
printf stale > build_dir/target-test/iping-0.1.0/agent
mkdir -p /artifacts/bin/packages/test/iping
printf core > /artifacts/bin/packages/test/iping/iping-mihomo_1.19.32-r1_test.ipk
printf stale > /artifacts/bin/packages/test/iping/iping_0.1.0-r1_test.ipk
save
rm -rf build_dir staging_dir bin
restore
test "$(cat staging_dir/hostpkg/lib/go-cross/go)" = compiler
test -f bin/packages/test/iping/iping-mihomo_1.19.32-r1_test.ipk
test ! -e bin/packages/test/iping/iping_0.1.0-r1_test.ipk
test ! -e build_dir/target-test/iping-0.1.0
''')

    def test_different_sdk_or_corrupt_snapshot_falls_back_to_a_cold_build(self):
        self.check('''
restore
mkdir -p build_dir/hostpkg staging_dir/hostpkg /artifacts/bin
printf old > staging_dir/hostpkg/old-sdk
save
rm -rf build_dir staging_dir bin
SDK_IMAGE_ID=new-sdk restore
test ! -e staging_dir/hostpkg/old-sdk
printf invalid > /ci-cache/states/openwrt-24.10-x86_64/state.tar.gz
restore
test ! -e staging_dir/hostpkg/old-sdk
''')

    def check(self, commands):
        shell = '''set -euo pipefail
mkdir -p /builder /ci-cache
cd /builder
printf sdk-version > version.buildinfo
restore() { bash /cache.sh restore; }
save() { bash /cache.sh save; }
''' + commands
        created = subprocess.run(['docker', 'create', '-e', 'SDK_IMAGE_ID=test-sdk',
                                  '-e', 'SDK_SLOT=openwrt-24.10-x86_64', IMAGE,
                                  'bash', '-c', shell], capture_output=True, text=True, check=True)
        container = created.stdout.strip()
        try:
            subprocess.run(['docker', 'cp', str(SCRIPT), container + ':/cache.sh'], check=True,
                           capture_output=True)
            result = subprocess.run(['docker', 'start', '--attach', container], capture_output=True, text=True)
            status = subprocess.check_output(['docker', 'inspect', '--format', '{{.State.ExitCode}}', container], text=True)
            self.assertEqual(status.strip(), '0', result.stdout + result.stderr)
        finally:
            subprocess.run(['docker', 'rm', '--force', container], check=True, capture_output=True)


if __name__ == '__main__':
    unittest.main()
