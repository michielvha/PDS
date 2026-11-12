"""Run unit tests normally; set PDS_STORAGE_INTEGRATION=1 for disposable Fedora tests."""
import json
import os
from pathlib import Path
import re
import shlex
import socket
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'bash/fedora/storage_maintenance.sh'
GIB = 1024 ** 3
FEDORA_IMAGE = (
    'registry.fedoraproject.org/fedora:43@sha256:'
    'cd9d25651b6c27cfc2d65883e1162e42dfd57f53cbdbcdc891fd99cbb38915ed'
)

USAGE = """Overall:
    Device size: 750016004096
    Device missing: 0
    Free (statfs, df): 141566332928
Data,single: Size:554643226624, Used:528957124608 (95.37%)
Metadata,RAID1: Size:39711670272, Used:39175995392 (98.65%)
System,RAID1: Size:33554432, Used:81920 (0.24%)
Unallocated:
    /dev/sda3 1048576
    /dev/nvme0n1p1 115881279488
"""

FAKE_COMMAND = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import stat
import sys

state_path = Path(os.environ['PDS_TEST_STATE'])
state = json.loads(state_path.read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ['PDS_TEST_LOG']).open('a') as log:
    log.write(json.dumps({'name': name, 'args': args,
                          'cache': os.environ.get('GOCACHE'),
                          'goflags': os.environ.get('GOFLAGS'),
                          'goenv': os.environ.get('GOENV')}) + '\n')
home = Path(state['home'])
cache = home / '.cache/go-build'
if name == 'uname':
    print('Linux')
elif name == 'id':
    print(state['uid'] if state['user'] in args else state['current_uid'])
elif name == 'getent':
    if args != ['passwd', state['user']]:
        sys.exit(2)
    print(f"{state['user']}:x:{state['uid']}:1000:test:{home}:/bin/bash")
elif name == 'realpath':
    try:
        print(Path(args[-1]).resolve(strict=True))
    except FileNotFoundError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
elif name == 'stat':
    path = Path(args[-1])
    info = path.stat(follow_symlinks=False)
    value = args[args.index('-c') + 1]
    fields = {'%u': str(state['uid']), '%g': '1000',
              '%a': oct(stat.S_IMODE(info.st_mode))[2:],
              '%h': str(info.st_nlink), '%i': str(info.st_ino),
              '%d': str(info.st_dev)}
    if (path == cache or cache in path.parents) and state.get('subvolume', True):
        fields['%d'] = str(info.st_dev + 1)
        if path == cache:
            fields['%i'] = '256'
        if path == cache / 'aa' and state.get('nested_mount'):
            fields['%d'] = str(info.st_dev + 2)
    for key, replacement in fields.items():
        value = value.replace(key, replacement)
    print(value)
elif name == 'findmnt':
    print(state.get('cache_mount_target', '/') if 'TARGET' in args
          else state.get('filesystem', 'btrfs'))
elif name == 'pgrep':
    if state.get('busy'):
        print('12345')
    else:
        sys.exit(1)
elif name == 'du':
    if state.get('du_error'):
        print('injected cache permission failure', file=sys.stderr)
        sys.exit(1)
    print(f"{state['cache_bytes'] if args[-1] == str(cache) else state.get('browser_bytes', 0)}\t{args[-1]}")
elif name == 'btrfs':
    if args[:2] == ['filesystem', 'usage']:
        if state.get('usage_error'):
            print('injected Btrfs failure', file=sys.stderr)
            sys.exit(1)
        print(state['usage'])
    elif args[:2] == ['subvolume', 'show']:
        if not state.get('subvolume', True):
            print('not a subvolume', file=sys.stderr)
            sys.exit(1)
        print('Subvolume ID: 300')
    elif args[:2] == ['device', 'stats']:
        if state.get('device_error'):
            print('[/dev/sda3].write_io_errs 1')
            sys.exit(64)
        print('[/dev/sda3].write_io_errs 0')
    else:
        print(f'unexpected Btrfs command: {args}', file=sys.stderr)
        sys.exit(2)
elif name == 'go':
    if args == ['env', 'GOCACHE']:
        print(state.get('configured_cache', str(cache)))
    elif args == ['clean', '-cache']:
        if state.get('go_error'):
            print('injected Go cleanup failure', file=sys.stderr)
            sys.exit(1)
        assert os.environ.get('GOCACHE') == str(cache)
        flags = os.environ.get('GOFLAGS') or (
            state.get('persistent_flags', '') if os.environ.get('GOENV') != 'off' else '')
        if '-modcache' in flags.split() and (home / 'go/pkg/mod').exists():
            shutil.rmtree(home / 'go/pkg/mod')
        for path in cache.iterdir():
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()
        state['cache_bytes'] = 0
        state_path.write_text(json.dumps(state))
    else:
        print(f'unexpected Go command: {args}', file=sys.stderr)
        sys.exit(2)
elif name in ('runuser', 'notify-send'):
    if state.get('notification_error'):
        print('injected desktop notification failure', file=sys.stderr)
        sys.exit(1)
else:
    print(f'unexpected command: {name}', file=sys.stderr)
    sys.exit(2)
'''


class StorageUnitTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='pds-storage-unit-')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.home = self.base / 'home'
        self.cache = self.home / '.cache/go-build'
        self.cache.mkdir(parents=True)
        self.module = self.home / 'go/pkg/mod/keep'
        self.module.parent.mkdir(parents=True)
        self.module.write_text('module data must remain')
        self.profile = self.home / '.config/profile-keep'
        self.profile.parent.mkdir(parents=True)
        self.profile.write_text('profile data must remain')
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        stub = self.bin / 'fake-command'
        stub.write_text(FAKE_COMMAND)
        stub.chmod(0o755)
        for name in ('uname', 'id', 'getent', 'realpath', 'stat', 'findmnt',
                     'pgrep', 'du', 'btrfs', 'go', 'runuser', 'notify-send'):
            (self.bin / name).symlink_to(stub.name)
        self.state_path = self.base / 'state.json'
        self.log = self.base / 'commands.jsonl'
        self.state = {
            'user': 'pds-test', 'uid': 1000, 'current_uid': 1000,
            'home': str(self.home), 'cache_bytes': 8192, 'usage': USAGE,
        }
        self.environment = dict(os.environ, HOME=str(self.home), USER='pds-test',
                                LOGNAME='pds-test', PDS_TEST_STATE=str(self.state_path),
                                PDS_TEST_LOG=str(self.log),
                                PATH=str(self.bin) + os.pathsep + os.environ['PATH'])

    def run_script(self, mode, *, root=False, **state):
        self.state.update(state)
        self.state['current_uid'] = 0 if root else 1000
        self.state_path.write_text(json.dumps(self.state))
        return subprocess.run(
            ['bash', str(SCRIPT), mode, '--user', 'pds-test',
             '--go', str(self.bin / 'go')],
            env=self.environment, text=True, capture_output=True, timeout=20)

    def commands(self, name):
        if not self.log.exists():
            return []
        return [entry for line in self.log.read_text().splitlines()
                if (entry := json.loads(line))['name'] == name]

    def test_ac02_per_device_warning_despite_aggregate_space(self):
        result = self.run_script('check', root=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('/dev/sda3', result.stdout)
        self.assertIn('1048576', result.stdout)
        self.assertIn('WARN', result.stdout)
        self.assertIn('SKIP', result.stdout)
        forbidden = ('balance', 'delete', 'resize', 'convert')
        for entry in self.commands('btrfs'):
            self.assertFalse(any(word in entry['args'] for word in forbidden), entry)
        self.assertFalse(self.commands('go'))

    def test_ac02_desktop_attempt_and_delivery_error_are_explicit(self):
        runtime = self.base / 'runtime'
        runtime.mkdir()
        with socket.socket(socket.AF_UNIX) as bus:
            bus.bind(str(runtime / 'bus'))
            for failed in (False, True):
                with self.subTest(failed=failed):
                    self.state['notification_error'] = failed
                    self.state_path.write_text(json.dumps(self.state))
                    command = (
                        f'source {shlex.quote(str(SCRIPT))}; '
                        '_pds_storage_notify pds-test 1000 "storage warning" '
                        + shlex.quote(str(runtime))
                    )
                    result = subprocess.run(
                        ['bash', '-c', command], env=self.environment,
                        text=True, capture_output=True, timeout=20)
                    self.assertEqual(result.returncode, 2 if failed else 0,
                                     result.stdout + result.stderr)
                    if failed:
                        self.assertIn('injected desktop notification failure', result.stderr)
            attempts = self.commands('runuser')
            self.assertEqual(len(attempts), 2)
            self.assertTrue(all('pds-test' in attempt['args'] for attempt in attempts))

    def test_ac02_healthy_headroom_succeeds(self):
        usage = USAGE.replace('/dev/sda3 1048576', f'/dev/sda3 {12 * GIB}')
        result = self.run_script('check', root=True, usage=usage)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_ac03_incomplete_or_failed_measurement_is_not_healthy(self):
        for state in ({'usage': 'Overall:\nDevice size: 1\n'},
                      {'usage_error': True}, {'du_error': True},
                      {'device_error': True}, {'filesystem': 'ext4'}):
            with self.subTest(state=state):
                result = self.run_script('check', root=True, **state)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.state = {**self.state, 'usage': USAGE, 'usage_error': False,
                              'du_error': False, 'device_error': False,
                              'filesystem': 'btrfs'}

    def test_ac03_symlink_cache_is_refused_without_touching_target(self):
        outside = self.base / 'outside'
        outside.mkdir()
        keep = outside / 'keep'
        keep.write_text('not a cache')
        self.cache.rmdir()
        self.cache.symlink_to(outside, target_is_directory=True)
        result = self.run_script('cleanup-go', cache_bytes=30 * GIB)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(keep.read_text(), 'not a cache')
        self.assertFalse(self.commands('go'))

    def test_ac03_plain_directory_is_not_treated_as_prepared_cache(self):
        result = self.run_script('cleanup-go', cache_bytes=30 * GIB, subvolume=False)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertFalse(self.commands('go'))

    def test_ac03_mount_alias_is_not_treated_as_a_nested_cache_subvolume(self):
        result = self.run_script('cleanup-go', cache_bytes=30 * GIB,
                                 cache_mount_target=str(self.cache))
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertFalse(self.commands('go'))

    def test_ac03_custom_go_cache_is_not_silently_reconfigured(self):
        configured = self.base / 'different-cache'
        configured.mkdir()
        keep = configured / 'keep'
        keep.write_text('custom cache data')
        result = self.run_script('prepare-go-cache', configured_cache=str(configured))
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(keep.read_text(), 'custom cache data')
        self.assertFalse(any(entry['args'] == ['clean', '-cache']
                             for entry in self.commands('go')))

    def test_ac03_root_cannot_run_user_cache_cleanup(self):
        result = self.run_script('cleanup-go', root=True, cache_bytes=30 * GIB)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertFalse(self.commands('go'))

    def test_ac03_unknown_files_and_nested_mounts_are_preserved(self):
        unknown = self.cache / 'manual-source.txt'
        unknown.write_text('preserve unknown data')
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(unknown.read_text(), 'preserve unknown data')
        self.assertFalse(self.commands('go'))

    def test_ac03_nested_filesystem_is_not_traversed_by_native_cleanup(self):
        nested = self.cache / 'aa'
        nested.mkdir()
        keep = nested / ('a' * 64 + '-d')
        keep.write_text('another filesystem')
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB, nested_mount=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(keep.read_text(), 'another filesystem')
        self.assertFalse(self.commands('go'))

    def test_ac05_sourcing_preserves_options_traps_and_does_not_run_tools(self):
        command = (
            'set -eu; trap ":" EXIT; before_options=$-; before_trap=$(trap -p EXIT); '
            f'source {shlex.quote(str(SCRIPT))}; '
            'test "$before_options" = "$-"; test "$before_trap" = "$(trap -p EXIT)"; '
            'declare -F storage_maintenance >/dev/null'
        )
        self.state_path.write_text(json.dumps(self.state))
        result = subprocess.run(['bash', '-c', command], env=self.environment,
                                text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.log.exists(), 'sourcing executed native tools')

    def test_ac06_browser_budget_is_warning_only_and_output_is_plain(self):
        browser = self.home / '.cache/ms-playwright-mcp'
        browser.mkdir()
        keep = browser / 'browser-keep'
        keep.write_text('installed browser')
        result = self.run_script('check', root=True, browser_bytes=16 * GIB)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('browser', result.stdout.lower())
        self.assertNotIn('\x1b', result.stdout + result.stderr)
        self.assertEqual(keep.read_text(), 'installed browser')

    def test_ac08_budget_boundary_and_busy_build_skip(self):
        for size in (0, 20 * GIB):
            with self.subTest(size=size):
                result = self.run_script('cleanup-go', cache_bytes=size)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn('SKIP', result.stdout)
        result = self.run_script('cleanup-go', cache_bytes=20 * GIB + 1, busy=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('busy', (result.stdout + result.stderr).lower())
        self.assertFalse(self.commands('go'))

    def test_ac08_cleanup_uses_only_native_build_cache_and_preserves_other_data(self):
        (self.cache / 'aa').mkdir()
        (self.cache / 'aa' / ('a' * 64 + '-d')).write_text('rebuildable')
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        cleanup = [entry for entry in self.commands('go')
                   if entry['args'] == ['clean', '-cache']]
        self.assertEqual(len(cleanup), 1)
        self.assertEqual(cleanup[0]['cache'], str(self.cache))
        self.assertEqual(self.module.read_text(), 'module data must remain')
        self.assertEqual(self.profile.read_text(), 'profile data must remain')

    def test_ac08_native_cleanup_failure_is_visible(self):
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB, go_error=True)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('injected Go cleanup failure', result.stderr)

    def test_ac03_ambient_flags_cannot_add_module_cleanup(self):
        self.environment['GOFLAGS'] = '-modcache'
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.module.exists(), 'ambient GOFLAGS deleted the module cache')
        self.assertEqual(self.module.read_text(), 'module data must remain')

    def test_ac03_persistent_flags_cannot_add_module_cleanup(self):
        self.environment.pop('GOFLAGS', None)
        result = self.run_script('cleanup-go', cache_bytes=21 * GIB,
                                 persistent_flags='-modcache')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.module.exists(), 'persistent GOFLAGS deleted the module cache')
        self.assertEqual(self.module.read_text(), 'module data must remain')

    def test_invalid_mode_and_numeric_output_fail_explicitly(self):
        result = self.run_script('not-a-mode')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertTrue(result.stderr)
        result = self.run_script('cleanup-go', cache_bytes='not-a-number')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)

    def test_ac03_missing_prerequisite_is_an_explicit_failure(self):
        (self.bin / 'getent').unlink()
        self.state_path.write_text(json.dumps(self.state))
        environment = dict(self.environment, PATH=str(self.bin))
        result = subprocess.run(
            ['/bin/bash', str(SCRIPT), 'check', '--user', 'pds-test'],
            env=environment, text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('getent', result.stderr)


@unittest.skipUnless(os.environ.get('PDS_STORAGE_INTEGRATION') == '1',
                     'set PDS_STORAGE_INTEGRATION=1 for disposable Fedora/Btrfs')
class StorageFedoraIntegration(unittest.TestCase):
    @classmethod
    def docker(cls, *args, check=True, timeout=120, input=None):
        result = subprocess.run(['docker', *args], text=True, capture_output=True,
                                input=input, timeout=timeout)
        if check and result.returncode:
            raise AssertionError(f'docker {args} failed:\n{result.stdout}\n{result.stderr}')
        return result

    @classmethod
    def execute(cls, command, *, user=None, check=True, timeout=120):
        prefix = ['exec']
        if user:
            prefix += ['--user', user, '--env', 'HOME=/test-btrfs/home/pds-test',
                       '--env', 'XDG_RUNTIME_DIR=/run/user/1000',
                       '--env', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus']
        return cls.docker(*prefix, cls.container, 'bash', '-euc', command,
                          check=check, timeout=timeout)

    @classmethod
    def wait_for(cls, command, seconds=40):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            result = cls.execute(command, check=False, timeout=10)
            if result.returncode == 0:
                return result.stdout
            time.sleep(1)
        diagnostics = cls.execute(
            'systemctl --failed --no-pager; journalctl -b -n 40 --no-pager',
            check=False, timeout=15)
        raise AssertionError(f'Native readiness did not succeed: {command}\n'
                             f'{result.stdout}\n{result.stderr}\n'
                             f'{diagnostics.stdout}\n{diagnostics.stderr}')

    @classmethod
    def setUpClass(cls):
        cls.container = 'pds-storage-' + uuid.uuid4().hex[:12]
        cls.image = os.environ.get('PDS_STORAGE_TEST_IMAGE',
                                   'pds-storage-fixture:fedora43-consumers-v1')
        if cls.docker('image', 'inspect', cls.image, check=False).returncode:
            fixture = (
                f'FROM {FEDORA_IMAGE}\n'
                'RUN dnf -y install btrfs-progs golang systemd python3 util-linux '
                'procps-ng dbus-daemon libnotify shadow-utils findutils jq npm podman '
                'moby-engine docker-cli docker-buildx python3-pip && dnf clean all\n'
                'RUN python3 -m pip install --no-cache-dir uv==0.10.9\n'
                'ENV container=docker\nSTOPSIGNAL SIGRTMIN+3\nCMD ["/sbin/init"]\n'
            )
            cls.docker('build', '-t', cls.image, '-', input=fixture, timeout=600)
        cls.loops = []
        cls.loop_files = []
        cls.users = [1000]
        cls.addClassCleanup(cls.cleanup_fixture)
        cls.docker('run', '-d', '--name', cls.container, '--privileged',
                   '--cgroupns=private', '--tmpfs', '/run', '--tmpfs', '/run/lock',
                   cls.image)
        cls.wait_for('systemctl show -p Version --value')
        cls.execute('mkdir -p /work/bash/fedora /work/packaging/bin /work/lib/common/utils; '
                    'printf "fixture_noop() { :; }\\n" >/work/lib/common/utils/fixture.sh; '
                    'printf "0.0.0\\n" >/work/lib/VERSION')
        cls.docker('cp', str(SCRIPT), cls.container + ':/work/bash/fedora/storage_maintenance.sh')
        cls.docker('cp', str(ROOT / 'bash/fedora/storage_consumers.sh'),
                   cls.container + ':/work/bash/fedora/storage_consumers.sh')
        cls.docker('cp', str(ROOT / 'packaging/bin/pds'),
                   cls.container + ':/work/packaging/bin/pds')
        cls.cli_command = (
            'PDS_LIB_DIR=/work/lib bash /work/packaging/bin/pds help; '
            'PDS_LIB_DIR=/work/lib bash /work/packaging/bin/pds info'
        )
        cls.cli_before = cls.execute(cls.cli_command).stdout
        cls.execute('mkdir -p /var/tmp/pds-loop /test-btrfs; '
                    'truncate -s 12G /var/tmp/pds-loop/a.img /var/tmp/pds-loop/b.img')
        cls.loop_files = ['/var/tmp/pds-loop/a.img', '/var/tmp/pds-loop/b.img']
        for image in ('a.img', 'b.img'):
            device = cls.execute('losetup --find --show /var/tmp/pds-loop/' + image).stdout.strip()
            if not re.fullmatch(r'/dev/loop[0-9]+', device):
                raise AssertionError(f'Unexpected owned loop device: {device}')
            cls.loops.append(device)
        devices = ' '.join(shlex.quote(path) for path in cls.loops)
        cls.execute(
            f'mkfs.btrfs -f -d single -m raid1 {devices}; '
            f'mount {shlex.quote(cls.loops[0])} /test-btrfs; '
            'btrfs subvolume create /test-btrfs/home; '
            'mkdir -p /test-btrfs/home/pds-test; '
            'useradd -u 1000 -d /test-btrfs/home/pds-test -M pds-test; '
            'chown 1000:1000 /test-btrfs/home/pds-test; '
            'mkdir -p /etc/btrbk; '
            'printf "snapshot_preserve 2d\\ntarget_preserve 14d 8w 6m\\n" >/etc/btrbk/btrbk.conf; '
            'loginctl enable-linger pds-test; systemctl start user@1000.service')
        cls.wait_for('test -S /run/user/1000/bus')

    @classmethod
    def cleanup_fixture(cls):
        if not hasattr(cls, 'container'):
            return
        managers = ' '.join(f'user@{uid}.service' for uid in cls.users)
        cleanup = cls.execute(f'systemctl stop {managers} || true; '
                              'umount /test-btrfs', check=False)
        for image in cls.loop_files:
            associated = cls.execute('losetup -j ' + shlex.quote(image))
            for line in associated.stdout.splitlines():
                device = line.split(':', 1)[0]
                if not re.fullmatch(r'/dev/loop[0-9]+', device):
                    raise AssertionError(f'Cannot safely detach unexpected device: {line}')
                cls.execute('losetup -d ' + shlex.quote(device))
        removed = cls.docker('rm', '-f', cls.container, check=False)
        if removed.returncode:
            raise AssertionError(f'Owned container cleanup failed:\n{removed.stderr}\n'
                                 f'{cleanup.stdout}\n{cleanup.stderr}')

    def test_ac01_ac03_ac04_ac05_ac07_ac08_native_cache_and_timer_lifecycle(self):
        script = '/work/bash/fedora/storage_maintenance.sh'
        home = '/test-btrfs/home/pds-test'
        cache = home + '/.cache/go-build'
        self.execute(
            'mkdir -p ~/.cache/go-build ~/project ~/go/pkg/mod ~/.config; '
            'printf keep >~/go/pkg/mod/pds-keep; printf profile >~/.config/pds-keep; '
            'printf source >~/.cache/go-build/not-a-go-file', user='1000:1000')
        refused = self.execute(
            f'bash {script} prepare-go-cache --user pds-test --go /usr/bin/go',
            user='1000:1000', check=False)
        self.assertEqual(refused.returncode, 2, refused.stdout + refused.stderr)
        self.execute('test "$(cat ~/.cache/go-build/not-a-go-file)" = source; '
                     'rm ~/.cache/go-build/not-a-go-file; chmod 0750 ~/.cache/go-build; '
                     'mkdir ~/fault-bin; '
                     'printf \'#!/bin/bash\\nkill -TERM "$PPID"\\nexit 130\\n\' >~/fault-bin/mv; '
                     'chmod +x ~/fault-bin/mv',
                     user='1000:1000')
        interrupted = self.execute(
            f'PATH="$HOME/fault-bin:$PATH" bash {script} prepare-go-cache '
            '--user pds-test --go /usr/bin/go', user='1000:1000', check=False)
        self.assertNotEqual(interrupted.returncode, 0)
        self.execute('test "$(cat ~/go/pkg/mod/pds-keep)" = keep; '
                     'test "$(cat ~/.config/pds-keep)" = profile; '
                     'rm ~/fault-bin/mv; rmdir ~/fault-bin',
                     user='1000:1000')
        self.execute(
            f'bash {script} prepare-go-cache --user pds-test --go /usr/bin/go',
            user='1000:1000')
        self.assertEqual(self.execute(f'stat -c "%u:%g:%a" {cache}').stdout.strip(),
                         '1000:1000:750')
        repeated = self.execute(
            f'bash {script} prepare-go-cache --user pds-test --go /usr/bin/go',
            user='1000:1000')
        self.assertIn('SKIP', repeated.stdout)
        self.execute(f'btrfs subvolume delete {cache}; btrfs filesystem sync /test-btrfs')
        self.execute(
            f'bash {script} prepare-go-cache --user pds-test --go /usr/bin/go',
            user='1000:1000')
        self.execute(f'btrfs subvolume show {cache}')
        self.execute(
            'printf \'package main\\nimport "fmt"\\nfunc main(){fmt.Println("fixture")}\\n\' '
            '>~/project/main.go; '
            'go telemetry off; cd ~/project; '
            'CGO_ENABLED=0 GOTOOLCHAIN=local go build -o app main.go; ./app',
            user='1000:1000', timeout=180)
        self.assertEqual(self.execute('go env GOCACHE', user='1000:1000').stdout.strip(),
                         cache)
        before_source = self.execute(f'sha256sum {home}/project/main.go').stdout
        before_backup = self.execute('sha256sum /etc/btrbk/btrbk.conf').stdout
        self.execute(
            'mkdir /test-btrfs/snapshots; '
            'btrfs subvolume snapshot -r /test-btrfs/home /test-btrfs/snapshots/home')
        self.execute(
            'test -z "$(find /test-btrfs/snapshots/home/pds-test/.cache/go-build '
            '-mindepth 1 -print -quit)"')
        self.execute(
            'mkdir -p ~/.cache/go-build/aa; '
            'truncate -s 21G ~/.cache/go-build/aa/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d',
            user='1000:1000')
        self.execute('btrfs filesystem sync /test-btrfs')
        before_free = int(self.execute(
            "btrfs filesystem usage -b /test-btrfs | "
            "awk '/Free \\(statfs, df\\):/ {print $4}'").stdout.strip())
        cleanup = self.execute(
            f'bash {script} cleanup-go --user pds-test --go /usr/bin/go',
            user='1000:1000', timeout=180)
        self.execute('btrfs filesystem sync /test-btrfs')
        after_free = int(self.execute(
            "btrfs filesystem usage -b /test-btrfs | "
            "awk '/Free \\(statfs, df\\):/ {print $4}'").stdout.strip())
        self.assertGreater(after_free, before_free, cleanup.stdout + cleanup.stderr)
        self.assertEqual(self.execute(f'sha256sum {home}/project/main.go').stdout, before_source)
        self.assertEqual(self.execute('sha256sum /etc/btrbk/btrbk.conf').stdout, before_backup)
        self.execute(f'test "$(cat {home}/go/pkg/mod/pds-keep)" = keep; '
                     f'test "$(cat {home}/.config/pds-keep)" = profile')
        self.execute('printf "unrelated administrator content\\n" '
                     '>/etc/systemd/system/pds-btrfs-headroom.service')
        conflicting = self.execute(
            f'bash {script} install --user pds-test --mount /test-btrfs --go /usr/bin/go',
            check=False)
        self.assertEqual(conflicting.returncode, 2, conflicting.stdout + conflicting.stderr)
        self.execute('grep -Fx "unrelated administrator content" '
                     '/etc/systemd/system/pds-btrfs-headroom.service; '
                     'test ! -e /usr/local/libexec/pds-storage-maintenance; '
                     'rm /etc/systemd/system/pds-btrfs-headroom.service')
        self.execute("""cat >/etc/systemd/system/pds-storage-fixture-unrelated.service <<'UNIT'
[Service]
Type=oneshot
ExecStart=/usr/bin/true
UNIT
cat >/etc/systemd/system/pds-storage-fixture-unrelated.timer <<'UNIT'
[Timer]
OnCalendar=daily
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now pds-storage-fixture-unrelated.timer
""")
        unrelated = self.execute(
            'sha256sum /etc/systemd/system/pds-storage-fixture-unrelated.*').stdout
        unit_go = '/usr/local/bin/pds${go}%fixture'
        self.execute('mkdir -p /usr/local/bin; ln -s /usr/bin/go ' + shlex.quote(unit_go))
        for _ in range(2):
            self.execute(
                f'umask 077; bash {script} install --user pds-test --mount /test-btrfs '
                f'--go {shlex.quote(unit_go)}')
        installed = self.execute(
            'sha256sum /etc/systemd/system/pds-btrfs-headroom.service').stdout
        changed_mount = self.execute(
            f'bash {script} install --user pds-test --mount / --go /usr/bin/go',
            check=False)
        self.assertEqual(changed_mount.returncode, 2)
        self.assertEqual(self.execute(
            'sha256sum /etc/systemd/system/pds-btrfs-headroom.service').stdout, installed)
        self.execute(
            'systemd-analyze verify /etc/systemd/system/pds-btrfs-headroom.service '
            '/etc/systemd/system/pds-btrfs-headroom.timer')
        self.execute('systemctl start pds-btrfs-headroom.service; '
                     'test "$(systemctl show -p Result --value pds-btrfs-headroom.service)" = success')
        self.execute('systemctl --user start pds-go-cache-clean.service',
                     user='1000:1000')
        self.execute(
            'systemctl --user is-enabled pds-go-cache-clean.timer; '
            'systemctl --user cat pds-go-cache-clean.timer | grep -Fx Persistent=true; '
            'systemctl --user cat pds-go-cache-clean.timer | grep -F OnCalendar=',
            user='1000:1000')
        self.execute(
            'systemctl --user stop pds-go-cache-clean.timer; '
            'systemctl --user stop pds-cache-user.timer; '
            'mkdir -p ~/.local/share/systemd/timers; '
            'touch -d "2 days ago" ~/.local/share/systemd/timers/stamp-pds-go-cache-clean.timer; '
            'touch -d "2 days ago" ~/.local/share/systemd/timers/stamp-pds-cache-user.timer; '
            'mkdir -p ~/.cache/go-build/aa; '
            'truncate -s 21G ~/.cache/go-build/aa/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d',
            user='1000:1000')
        self.execute(
            'systemctl stop pds-cache-docker.timer; '
            'mkdir -p /var/lib/systemd/timers; '
            'touch -d "2 days ago" /var/lib/systemd/timers/stamp-pds-cache-docker.timer')
        self.execute("""cat >/var/tmp/pds-loop/boot.sh <<'BOOT'
#!/bin/bash
set -euo pipefail
a=$(losetup --find --show --nooverlap /var/tmp/pds-loop/a.img)
b=$(losetup --find --show --nooverlap /var/tmp/pds-loop/b.img)
btrfs device scan "$a" "$b"
mount -t btrfs "$a" /test-btrfs
BOOT
cat >/etc/systemd/system/pds-test-loop.service <<'UNIT'
[Unit]
Description=Restore only the disposable test's loopback filesystem
DefaultDependencies=no
Before=local-fs.target systemd-user-sessions.service user@1000.service
[Service]
Type=oneshot
ExecStart=/usr/bin/bash /var/tmp/pds-loop/boot.sh
RemainAfterExit=true
[Install]
WantedBy=local-fs.target
UNIT
systemctl daemon-reload
systemctl enable pds-test-loop.service
""")
        self.docker('restart', self.container, timeout=90)
        self.wait_for('test -S /run/user/1000/bus')
        self.wait_for(
            f'test ! -f {cache}/aa/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d',
            seconds=60)
        self.execute('systemctl is-active pds-btrfs-headroom.timer')
        self.execute('systemctl is-active pds-cache-docker.timer; '
                     'systemctl cat pds-cache-docker.timer | grep -Fx "OnCalendar=*-*-* 04:45:00"; '
                     'systemctl cat pds-cache-docker.timer | grep -Fx Persistent=true')
        self.execute('systemctl --user is-active pds-go-cache-clean.timer',
                     user='1000:1000')
        self.execute('systemctl --user is-active pds-cache-user.timer; '
                     'systemctl --user cat pds-cache-user.timer | grep -Fx "OnCalendar=*-*-* 05:15:00"; '
                     'systemctl --user cat pds-cache-user.timer | grep -Fx Persistent=true',
                     user='1000:1000')
        self.wait_for(
            'test "$(systemctl show -p ExecMainStartTimestampMonotonic --value '
            'pds-cache-docker.service)" != 0')
        self.execute(
            'test "$(systemctl --user show -p ExecMainStartTimestampMonotonic --value '
            'pds-cache-user.service)" != 0', user='1000:1000')
        self.execute(
            f'bash {script} uninstall --user pds-test --mount /test-btrfs')
        self.execute(
            f'test -d {cache}; test -f {home}/go/pkg/mod/pds-keep; '
            'test -f /etc/btrbk/btrbk.conf; '
            'test ! -e /etc/systemd/system/pds-btrfs-headroom.timer; '
            'test ! -e /etc/systemd/system/pds-cache-docker.timer; '
            'test ! -e /usr/local/libexec/pds-storage-consumers; '
            f'test ! -e {home}/.config/systemd/user/pds-go-cache-clean.timer; '
            f'test ! -e {home}/.config/systemd/user/pds-cache-user.timer')
        self.execute('systemctl is-active pds-storage-fixture-unrelated.timer; '
                     f'test "$(cat {home}/go/pkg/mod/pds-keep)" = keep; '
                     f'test "$(cat {home}/.config/pds-keep)" = profile')
        self.assertEqual(self.execute(
            'sha256sum /etc/systemd/system/pds-storage-fixture-unrelated.*').stdout, unrelated)
        self.assertEqual(self.execute('sha256sum /etc/btrbk/btrbk.conf').stdout, before_backup)
        self.assertEqual(self.execute(f'sha256sum {home}/project/main.go').stdout, before_source)
        self.assertEqual(self.execute(self.cli_command).stdout, self.cli_before)

    def test_ac03_ac08_native_go_flags_preserve_modules(self):
        script = '/work/bash/fedora/storage_maintenance.sh'
        home = '/test-btrfs/home/flags-user'
        cache = home + '/.cache/go-build'
        marker = home + '/go/pkg/mod/review-module/keep'
        self.execute(
            f'useradd -u 1001 -d {home} -M flags-user; mkdir -p {home}; '
            f'chown 1001:1001 {home}')
        self.users.append(1001)

        def as_user(command, **kwargs):
            return self.execute(
                f'runuser -u flags-user -- env HOME={home} '
                'XDG_RUNTIME_DIR=/run/user/1001 '
                'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus '
                'bash -euc ' + shlex.quote(command), **kwargs)

        as_user(
            'mkdir -p ~/.cache/go-build ~/go/pkg/mod/review-module; '
            'printf preserve-module >~/go/pkg/mod/review-module/keep; '
            'go env -w GOFLAGS=-modcache')
        settings = as_user('sha256sum ~/.config/go/env').stdout
        as_user(f'bash {script} prepare-go-cache --user flags-user --go /usr/bin/go')
        as_user(f'test "$(cat {marker})" = preserve-module')
        as_user(
            'mkdir -p ~/.cache/go-build/aa; '
            'truncate -s 21G ~/.cache/go-build/aa/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d')
        as_user(f'GOFLAGS=-modcache bash {script} cleanup-go --user flags-user --go /usr/bin/go')
        as_user(f'test "$(cat {marker})" = preserve-module')
        self.execute('loginctl enable-linger flags-user; systemctl start user@1001.service')
        self.wait_for('test -S /run/user/1001/bus')
        as_user(
            'systemctl --user set-environment GOFLAGS=-modcache; '
            'mkdir -p ~/.cache/go-build/aa; '
            'truncate -s 21G ~/.cache/go-build/aa/'
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d')
        self.execute(
            f'bash {script} install --user flags-user --mount /test-btrfs --go /usr/bin/go')
        as_user('systemctl --user start pds-go-cache-clean.service')
        as_user(f'test "$(cat {marker})" = preserve-module; '
                'test ! -f ~/.cache/go-build/aa/'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-d')
        self.assertEqual(as_user('sha256sum ~/.config/go/env').stdout, settings)
        self.execute(f'bash {script} uninstall --user flags-user --mount /test-btrfs')


if __name__ == '__main__':
    unittest.main(verbosity=2)
