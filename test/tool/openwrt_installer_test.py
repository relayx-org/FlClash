import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile

IMAGE = os.environ.get('IPING_INSTALLER_TEST_IMAGE')
SCRIPT = Path(__file__).resolve().parents[2] / 'openwrt/iping/files/iping-update'


@unittest.skipUnless(IMAGE, 'Set IPING_INSTALLER_TEST_IMAGE to run isolated BusyBox tests')
class OpenWrtInstallerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='iping-installer-test-')
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.root = root
        self.run_number = 0
        self.fixture, self.result = root / 'fixture', root / 'result'
        self.fixture.mkdir()
        self.result.mkdir()
        self.bin = self.fixture / 'bin'
        self.bin.mkdir()
        self.command('curl', '''out=''
while [ "$#" -gt 0 ]; do
 case "$1" in --output) shift; out=$1 ;; https://*) url=$1 ;; esac
 shift
done
echo "download $url" >> /result/events
case "$url" in */latest.json) cp /fixture/latest.json "$out" ;; *) cp /fixture/bundle.zip "$out" ;; esac
''')
        self.command('jsonfilter', '''while [ "$#" -gt 0 ]; do
 case "$1" in -e) shift; expression=$1 ;; -i) shift; input=$1 ;; esac
 shift
done
case "$expression" in
 '@.include_hash') sed 's/.*"include_hash":"//; s/".*//' "$input" ;;
 '@.schemaVersion'|'.schemaVersion') cat /fixture/schema ;;
 '@.packageId'|'.packageId') echo my.iping.client ;;
 '@.version'|'.version') echo 1.2.3 ;;
 '@.buildNumber'|'.buildNumber') echo 42 ;;
 *.url) cat /fixture/url ;;
 *.size) cat /fixture/size ;;
 *.sha256) cat /fixture/digest ;;
 *) exit 1 ;;
esac
''')
        parser = (self.bin / 'jsonfilter').read_text().replace('while [', 'if [ \"$1\" = -er ]; then expression=$2; set --; fi\nwhile [', 1)
        (self.bin / 'jq').write_text(parser)
        (self.bin / 'jq').chmod(0o755)
        self.command('uci', '''[ "$1" != -q ] || shift
case "$1" in
 get) cat "/result/uci/$2" 2>/dev/null ;;
 set) key=${2%%=*}; value=${2#*=}; mkdir -p /result/uci; printf '%s' "$value" > "/result/uci/$key" ;;
 delete) rm -f "/result/uci/$2" ;;
 commit) : ;;
 *) exit 1 ;;
esac
''')
        for manager in ['opkg', 'apk']:
            self.command(manager, """case "$1" in
 status|info) [ "$2" != "$(cat /fixture/missing-package 2>/dev/null)" ] || exit 1
  [ "$1" = info ] || echo 'Status: install ok installed'; exit 0 ;;
esac
echo "pm ${0##*/} $*" >> /result/events
[ "$1" != update ] || [ ! -f /fixture/update-fails ]
""")
        self.command('mv', """if [ -f /fixture/install-fails ] && [ "$2" = /usr/libexec/iping ] && [ ! -f /result/failed ]; then
 touch /result/failed
 exit 1
fi
exec /bin/busybox mv "$@"
""")
        self.command('systemctl', """echo "systemctl $*" >> /result/events
case "$*" in
 'is-active --quiet iping.service') test -f /result/running ;;
 'start iping.service') touch /result/running; echo 'service start' >> /result/events ;;
 'stop iping.service') rm -f /result/running; echo 'service stop' >> /result/events ;;
 'enable iping.service') echo 'service enable' >> /result/events ;;
 'disable --now iping.service') rm -f /result/running; echo 'service disable' >> /result/events ;;
 'disable --now iping-update.timer') if [ -f /etc/systemd/system/iping-update.timer ]; then rm /etc/systemd/system/iping-update.timer; else exit 1; fi ;;
 'enable --now iping-update.timer') test -f /etc/systemd/system/iping-update.timer ;;
esac
""")
        self.command('uname', 'cat /fixture/arch\n')
        self.command('ip', "echo '1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.2'\n")
        self.command('nft', 'exit 0\n')
        self.command('fw4', 'echo "fw4 $*" >> /result/events\n')
        self.command('crontab', '[ ! -f /fixture/schedule-fails ] || exit 1\nexec /bin/busybox crontab -c /etc/crontabs "$@"\n')
        self.command('df', '''for path; do :; done
if [ -f /fixture/no-space ] || { [ -f /fixture/flash-kb ] && [ "$path" != /tmp ]; }; then
 echo 'Filesystem 1024-blocks Used Available Capacity Mounted on'
 echo "test 8 8 $(cat /fixture/flash-kb 2>/dev/null || echo 0) 100% $path"
else /bin/busybox df "$@"; fi
''')
        self.command('xz', '''case "$1" in -dc) exec gzip -dc "$2" ;; *) exec gzip "$@" ;; esac
''')
        for name, body in {
            'service': '''. /fixture/iping.init
procd_open_instance() { :; }
procd_set_param() { :; }
procd_close_instance() { echo 'service start' >> /result/events; touch /result/running; }
case "$1" in
 running) test -f /result/running ;;
 start) start_service ;;
 stop) echo 'service stop' >> /result/events; rm -f /result/running ;;
 enable) echo 'service enable' >> /result/events; touch /result/enabled ;;
 disable) echo 'service disable' >> /result/events; rm -f /result/enabled ;;
esac
''',
            'cron': 'echo "cron $1" >> /result/events\n',
        }.items():
            path = self.fixture / name
            path.write_text('#!/bin/sh\n' + body)
            path.chmod(0o755)
        self.prepare()
        shutil.copyfile(SCRIPT.parent / 'iping.init', self.fixture / 'iping.init')

    def command(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/sh\nset -eu\n' + body)
        path.chmod(0o755)

    def prepare(self, branch='24.10', arch='x86_64', bad_archive=False, bad_package=False, padding=0):
        (self.fixture / 'arch').write_text(arch)
        (self.fixture / 'release').write_text(f"DISTRIB_RELEASE='{branch}.8'\nDISTRIB_ARCH='{arch}'\n")
        family = ('aarch64' if arch.startswith('aarch64') else 'mipsel' if arch.startswith('mipsel')
                  else 'mips' if arch.startswith('mips') else 'armv7' if arch.startswith('arm') else arch)
        self.names = ['agent', 'mihomo', 'update', 'iping.init', 'iping.conf', 'iping.upgrade', 'iping.service', 'iping-update.service', 'iping-update.timer', 'version', 'LICENSE']
        contents = {name: (name + '-new').encode() for name in self.names}
        contents['agent'] = b'#!/bin/sh\ncase "$1:$2" in config:get) cat "/result/uci/iping.config.$3" 2>/dev/null ;; config:set) printf "%s" "$4" > "/result/uci/iping.config.$3" ;; *) echo agent-new ;; esac\n'
        contents['mihomo'] = b'#!/bin/sh\necho mihomo-new\n'
        if padding:
            for name in ['agent', 'mihomo']:
                contents[name] += b'#' + b'a' * padding + b'\n'
        contents['version'] = b'1.2.3+42\n'
        contents['update'] = SCRIPT.read_bytes()
        contents['iping.init'] = (self.fixture / 'service').read_bytes()
        checksums = ''
        with zipfile.ZipFile(self.fixture / 'bundle.zip', 'w') as bundle:
            for name, content in contents.items():
                bundle.writestr(name, content)
                digest = '0' * 64 if bad_package else hashlib.sha256(content).hexdigest()
                checksums += digest + '  ' + name + '\n'
            bundle.writestr('SHA256SUMS', checksums)
        data = (self.fixture / 'bundle.zip').read_bytes()
        values = {'schema': '1', 'size': str(len(data)),
                  'digest': '0' * 64 if bad_archive else hashlib.sha256(data).hexdigest(),
                  'url': f'https://video.iping.my/releases/1.2.3+42/iPing-1.2.3-linux-agent-{family}.zip'}
        for key, value in values.items():
            (self.fixture / key).write_text(value)
        (self.fixture / 'latest.json').write_text(json.dumps({
            'schemaVersion': 1,
            'packageId': 'my.iping.client',
            'version': '1.2.3',
            'buildNumber': 42,
            'downloads': {f'linux-agent-{family}': {
                'url': values['url'], 'size': len(data), 'sha256': values['digest'],
            }},
        }))

    def run_installer(self, command='sh /installer', installed='', running=False, auto=None, extra=''):
        for name, value in [('installed', installed), ('running', '1' if running else ''),
                            ('auto', '' if auto is None else str(auto))]:
            (self.fixture / name).write_text(value)
        self.run_number += 1
        fixture = self.root / f'fixture-{self.run_number}'
        shutil.copytree(self.fixture, fixture)
        self.result = self.root / f'result-{self.run_number}'
        self.result.mkdir()
        (self.result / 'events').write_text('')
        bootstrap = '''set -eu
export PATH=/fixture/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /etc/init.d /etc/crontabs /usr/share/iping /usr/libexec/iping /result/uci
cp /fixture/release /etc/openwrt_release
if grep -q linux /etc/openwrt_release; then rm /etc/openwrt_release; fi
if grep -q 25.12 /etc/openwrt_release; then rm /fixture/bin/opkg; fi
cp /fixture/service /etc/init.d/iping
sed -i '2iOLD_TEST_INIT=1' /etc/init.d/iping
cp /fixture/cron /etc/init.d/cron
ln -s /installer /usr/libexec/iping/update
echo old-agent > /usr/libexec/iping/agent
mkdir -p /etc/config
echo user-config > /etc/config/iping
echo '0 1 * * * echo user-task' > /etc/crontabs/root
[ ! -f /fixture/legacy-schedule ] || echo '7 4 * * * /usr/libexec/iping/update --scheduled 2>&1 | logger -t iping-update # iping-auto-update' >> /etc/crontabs/root
[ ! -f /fixture/legacy-options ] || for option in auto_update update_minute; do echo 1 > "/result/uci/iping.config.$option"; done
[ ! -s /fixture/installed ] || cp /fixture/installed /usr/share/iping/version
[ ! -s /fixture/running ] || touch /result/running
[ ! -s /fixture/auto ] || cp /fixture/auto /result/uci/iping.config.auto_update
echo 192.168.1.1 > /result/uci/network.lan.ipaddr
''' + extra + '\nset +e\n' + command + '''
status=$?
cp /etc/crontabs/root /result/crontab
cat /usr/share/iping/version > /result/version 2>/dev/null || true
cat /usr/libexec/iping/agent > /result/agent 2>/dev/null || true
cat /etc/config/iping > /result/config 2>/dev/null || true
readlink /etc/init.d/iping > /result/init-link || true
cat /etc/init.d/iping > /result/init-content 2>/dev/null || true
if [ -f /etc/init.d/iping ] && [ ! -L /etc/init.d/iping ]; then echo regular > /result/init-file; fi
if [ -f /etc/systemd/system/iping-update.timer ] && [ ! -L /etc/systemd/system/iping-update.timer ]; then echo regular > /result/timer-unit; fi
ls /result/uci > /result/options 2>/dev/null || true
exit "$status"
'''
        container = subprocess.check_output(
            ['docker', 'create', '--network', 'none', IMAGE, 'sh', '-c', bootstrap],
            text=True).strip()
        try:
            for source, destination in [(SCRIPT, '/installer'), (fixture, '/fixture'),
                                        (self.result, '/result')]:
                subprocess.run(['docker', 'cp', str(source), f'{container}:{destination}'],
                               capture_output=True, check=True)
            result = subprocess.run(['docker', 'start', '--attach', container],
                                    capture_output=True, text=True, timeout=45)
            subprocess.run(['docker', 'cp', f'{container}:/result/.', str(self.result)],
                           capture_output=True, check=True)
            return result
        finally:
            subprocess.run(['docker', 'rm', '--force', container], capture_output=True)

    def events(self):
        return (self.result / 'events').read_text()

    def test_install_maps_firmware_architectures_to_portable_binaries(self):
        for branch, arch in [('24.10', 'x86_64'), ('25.12', 'aarch64_cortex-a53'),
                             ('24.10', 'mips_24kc'), ('26.1', 'mipsel_24kc'),
                             ('25.12', 'arm_cortex-a9_vfpv3-d16')]:
            with self.subTest(branch=branch, arch=arch):
                self.prepare(branch, arch)
                result = self.run_installer()
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn('pm ', self.events())
                self.assertIn('agent-new', (self.result / 'agent').read_text())
                self.assertEqual((self.result / 'config').read_text().strip(), 'user-config')
                self.assertEqual((self.result / 'init-link').read_text().strip(), '')
                self.assertEqual((self.result / 'init-file').read_text().strip(), 'regular')
                self.assertIn('service enable', self.events())
                self.assertIn('service start', self.events())
                self.assertEqual((self.result / 'version').read_text().strip(), '1.2.3+42')
                self.assertIn('http://192.168.1.1:19091/', result.stdout)
                cron = (self.result / 'crontab').read_text()
                self.assertIn('user-task', cron)
                self.assertNotIn('iping-auto-update', cron)

    def test_ready_address_drops_the_lan_prefix_length(self):
        self.prepare('24.10', 'aarch64_cortex-a53')
        result = self.run_installer(
            extra="echo '192.168.100.1/24 10.0.0.1/24' > /result/uci/network.lan.ipaddr")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('iPing is ready: http://192.168.100.1:19091/\n', result.stdout)

    def test_linux_systemd_uses_the_same_bundle_without_a_schedule(self):
        self.prepare('linux', 'x86_64')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        events = self.events()
        self.assertIn('service enable', events)
        self.assertIn('service start', events)
        self.assertIn('systemctl daemon-reload', events)
        self.assertNotIn('iping-update.timer', events)
        self.assertIn('http://192.168.1.2:19091/', result.stdout)
        self.assertFalse((self.result / 'timer-unit').exists())

    def test_checksums_and_space_are_checked_before_stopping_the_service(self):
        for failure in ['archive', 'package', 'space', 'url', 'schema']:
            with self.subTest(failure=failure):
                self.prepare(bad_archive=failure == 'archive', bad_package=failure == 'package')
                marker = self.fixture / 'no-space'
                if marker.exists(): marker.unlink()
                if failure == 'space': marker.touch()
                if failure == 'url': (self.fixture / 'url').write_text('https://other.test/wrong.zip')
                if failure == 'schema': (self.fixture / 'schema').write_text('2')
                result = self.run_installer('sh /installer update', installed='1.2.2+41', running=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('service stop', self.events())
                self.assertNotIn('pm ', self.events())

    def test_equal_or_older_releases_never_reinstall_or_restart(self):
        for installed in ['1.2.3+42', '1.2.3+43', '1.2.4+1', '2.0.0+1']:
            with self.subTest(installed=installed):
                result = self.run_installer('sh /installer update', installed=installed, running=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn('pm ', self.events())
                self.assertNotIn('service stop', self.events())

    def test_update_restores_old_binaries_and_running_service_on_activation_failure(self):
        (self.fixture / 'install-fails').touch()
        result = self.run_installer('sh /installer update', installed='1.2.2+41', running=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('service stop', self.events())
        self.assertIn('service start', self.events())
        self.assertTrue((self.result / 'running').exists())
        self.assertEqual((self.result / 'agent').read_text().strip(), 'old-agent')
        self.assertEqual((self.result / 'version').read_text().strip(), '1.2.2+41')

    def test_late_update_failure_restores_the_previous_init_file(self):
        (self.fixture / 'schedule-fails').touch()
        (self.fixture / 'legacy-schedule').touch()
        result = self.run_installer('sh /installer update', installed='1.2.2+41', running=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.result / 'running').exists())
        self.assertEqual((self.result / 'agent').read_text().strip(), 'old-agent')
        self.assertIn('OLD_TEST_INIT=1', (self.result / 'init-content').read_text())
        self.assertEqual((self.result / 'init-file').read_text().strip(), 'regular')

    def test_update_preserves_a_stopped_service(self):
        result = self.run_installer('sh /installer update', installed='1.2.2+41')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('service start', self.events())
        self.assertNotIn('service enable', self.events())

    def test_an_update_removes_a_schedule_left_by_an_older_release(self):
        (self.fixture / 'legacy-schedule').touch()
        (self.fixture / 'legacy-options').touch()
        result = self.run_installer('sh /installer update', installed='1.2.2+41')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        cron = (self.result / 'crontab').read_text()
        self.assertIn('user-task', cron)
        self.assertNotIn('iping-auto-update', cron)
        self.assertIn('cron restart', self.events())
        self.assertNotIn('auto_update', (self.result / 'options').read_text())
        self.assertNotIn('update_minute', (self.result / 'options').read_text())
        self.prepare('linux', 'x86_64')
        result = self.run_installer('sh /installer --scheduled', extra='mkdir -p /etc/systemd/system && touch /etc/systemd/system/iping-update.timer')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('.zip', self.events())
        self.assertIn('systemctl disable --now iping-update.timer', self.events())
        self.assertFalse((self.result / 'timer-unit').exists())

    def test_check_mode_reports_without_changing_anything(self):
        result = self.run_installer('sh /installer check', installed='1.2.2+41')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('pm ', self.events())
        self.assertNotIn('service ', self.events())
        (self.fixture / 'legacy-schedule').touch()
        result = self.run_installer('sh /installer check', installed='1.2.3+42')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('.zip', self.events())
        self.assertNotIn('iping-auto-update', (self.result / 'crontab').read_text())

    def test_another_update_lock_prevents_downloads_and_package_changes(self):
        result = self.run_installer('sh /installer update', extra='''mkdir -p /var/lock
exec 8>/var/lock/iping-update.lock
flock -n 8
''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('another iPing installation or update', result.stderr)
        self.assertEqual(self.events(), '')

    def test_uninstall_keeps_data_unless_purged(self):
        leftovers = 'ls /usr/libexec/iping /usr/share/iping /usr/bin/iping-update /etc/init.d/iping /lib/upgrade/keep.d/iping /etc/iping /etc/config/iping > /result/left 2>/dev/null'
        for purge in [False, True]:
            with self.subTest(purge=purge):
                result = self.run_installer(
                    'sh /installer && mkdir -p /etc/iping && echo session > /etc/iping/session.json && '
                    f'sh /installer uninstall{" --purge" if purge else ""}; status=$?; {leftovers}; (exit $status)')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                events = self.events()
                self.assertLess(events.rindex('service start'), events.index('service stop'))
                self.assertIn('service disable', events)
                left = (self.result / 'left').read_text().split()
                self.assertEqual(left, [] if purge else ['/etc/config/iping', '/etc/iping:', 'session.json'])
                cron = (self.result / 'crontab').read_text()
                self.assertIn('user-task', cron)
                self.assertNotIn('iping-auto-update', cron)

    def test_uninstall_removes_only_the_agents_own_firewall_include(self):
        include = '/etc/nftables.d/0-mihomo-auto-redirect.nft'
        for owned in [True, False]:
            with self.subTest(owned=owned):
                record = (f'hash=$(sha256sum {include} | cut -d " " -f 1)' if owned else 'hash=' + '0' * 64)
                result = self.run_installer(
                    f'sh /installer && mkdir -p /etc/nftables.d /etc/iping && echo rules > {include} && {record} && '
                    'printf \'{"device":"iping0","include_hash":"%s"}\' "$hash" > /etc/iping/network.json && '
                    f'sh /installer uninstall --purge; status=$?; ls /etc/nftables.d > /result/nft; (exit $status)')
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual((self.result / 'nft').read_text().strip(), '' if owned else '0-mihomo-auto-redirect.nft')
                self.assertEqual('fw4 reload' in self.events(), owned)

    def test_linux_uninstall_disables_units(self):
        self.prepare('linux', 'x86_64')
        result = self.run_installer('sh /installer && sh /installer uninstall; status=$?; '
                                    'ls /etc/systemd/system > /result/units; (exit $status)')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        events = self.events()
        self.assertIn('service disable', events)
        self.assertEqual((self.result / 'units').read_text().strip(), '')
        self.assertIn('remain in /etc/iping;', result.stdout)

    def test_partial_package_list_failure_still_installs_missing_packages(self):
        (self.fixture / 'update-fails').touch()
        (self.fixture / 'missing-package').write_text('kmod-inet-diag')
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('some package lists could not be updated', result.stderr)
        self.assertIn('pm opkg install kmod-inet-diag', self.events())

    def test_storage_is_checked_before_installing_packages(self):
        (self.fixture / 'missing-package').write_text('kmod-inet-diag')
        (self.fixture / 'flash-kb').write_text('0')
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('install to external storage with --dir', result.stderr)
        self.assertNotIn('pm ', self.events())

    def test_small_flash_keeps_compressed_programs_and_runs_them_from_tmp(self):
        self.prepare('24.10', 'aarch64_cortex-a53', padding=2 << 20)
        (self.fixture / 'flash-kb').write_text(str(8192 + 2048))
        check = ('/usr/libexec/iping/agent run > /result/ran && /usr/libexec/iping/mihomo -v >> /result/ran && '
                 'ls /usr/libexec/iping /tmp/iping-bin > /result/files')
        result = self.run_installer(f'sh /installer && {check}')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('storing the programs compressed', result.stdout)
        self.assertEqual((self.result / 'ran').read_text().split(), ['agent-new', 'mihomo-new'])
        files = (self.result / 'files').read_text().split()
        self.assertIn('agent.xz', files)
        self.assertIn('mihomo.version', files)
        self.assertIn('xz -dc', (self.result / 'agent').read_text())
        result = self.run_installer('sh /installer && echo 1.2.2+41 > /usr/libexec/iping/version && '
                                    f'sh /installer update && {check}')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.result / 'version').read_text().strip(), '1.2.3+42')
        self.assertEqual((self.result / 'ran').read_text().split(), ['agent-new', 'mihomo-new'])

    def test_update_with_room_for_one_copy_keeps_the_previous_programs_in_tmp(self):
        self.prepare(padding=1 << 20)
        for fails in [False, True]:
            with self.subTest(fails=fails):
                result = self.run_installer(
                    'sh /installer && echo old-agent > /usr/libexec/iping/agent && echo 1.2.2+41 > /usr/libexec/iping/version && '
                    f'echo {8192 + 1536} > /fixture/flash-kb && {"touch /fixture/install-fails && " if fails else ""}'
                    'sh /installer update', running=True)
                self.assertEqual(result.returncode != 0, fails, result.stdout + result.stderr)
                self.assertNotIn('storing the programs compressed', result.stdout)
                self.assertEqual((self.result / 'version').read_text().strip(), '1.2.2+41' if fails else '1.2.3+42')
                self.assertEqual((self.result / 'agent').read_text().startswith('old-agent'), fails)
                self.assertTrue((self.result / 'running').exists())

    def test_dir_option_moves_programs_and_data_to_external_storage(self):
        layout = ('readlink /usr/libexec/iping > /result/links; readlink /etc/iping >> /result/links; cat /etc/iping/session.json >> /result/links; '
                  'ls /usr/libexec > /result/libexec')
        result = self.run_installer(
            'mkdir -p /mnt/usb /etc/iping && echo session > /etc/iping/session.json && '
            'sh /installer --dir /mnt/usb/ && echo 1.2.2+41 > /usr/libexec/iping/version && '
            f'sh /installer update && {layout} && sh /installer uninstall --purge && ls -A /mnt/usb > /result/usb')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.result / 'links').read_text().split(),
                         ['/mnt/usb/iping/bin', '/mnt/usb/iping/data', 'session'])
        self.assertEqual((self.result / 'libexec').read_text().split(), ['iping'])
        self.assertEqual((self.result / 'usb').read_text().strip(), '')
        self.assertIn('1.2.2+41 -> 1.2.3+42', result.stdout)
        result = self.run_installer('sh /installer --dir usb')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('absolute path', result.stderr)

    def test_a_current_install_removes_a_retired_timer_without_downloading(self):
        self.prepare('linux', 'x86_64')
        result = self.run_installer(
            extra='mkdir -p /etc/systemd/system && touch /etc/systemd/system/iping-update.timer /etc/systemd/system/iping-update.service',
            installed='1.2.3+42')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('.zip', self.events())
        self.assertIn('systemctl disable --now iping-update.timer', self.events())
        self.assertFalse((self.result / 'timer-unit').exists())


if __name__ == '__main__':
    unittest.main()
