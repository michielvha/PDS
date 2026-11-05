"""Exercise the installed PDS update and SSH helpers in disposable Ubuntu only."""
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
import shlex
import signal
import socket
import subprocess
import tempfile
import threading
import time
import unittest


def command(args, *, env=None, check=True, input=None, timeout=30):
    return subprocess.run(args, text=True, capture_output=True, input=input,
                          timeout=timeout, check=check,
                          env=env if env is not None else os.environ.copy())


def pds(script, *, check=True):
    return command(['bash', '-euc', 'source /usr/share/pds/init.sh; ' + script], check=check)


@contextmanager
def apt_repository(packages=()):
    """Use only an owned file repository; never contact distribution mirrors."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        root.chmod(0o755)
        repo = root / 'repo'
        repo.mkdir(mode=0o755)
        for package in packages:
            (repo / package.name).write_bytes(package.read_bytes())
        index = subprocess.run(['dpkg-scanpackages', '.', '/dev/null'], cwd=repo,
                               text=True, capture_output=True, check=True)
        (repo / 'Packages').write_text(index.stdout)
        saved = {}
        paths = [Path('/etc/apt/sources.list')]
        paths += list(Path('/etc/apt/sources.list.d').glob('*.list'))
        paths += list(Path('/etc/apt/sources.list.d').glob('*.sources'))
        for path in paths:
            if path.exists():
                saved[path] = path.read_bytes()
                path.unlink()
        Path('/etc/apt/sources.list').write_text(f'deb [trusted=yes] file:{repo} ./\n')
        try:
            yield repo
        finally:
            Path('/etc/apt/sources.list').unlink(missing_ok=True)
            for path, content in saved.items():
                path.write_bytes(content)


def fixture_package(directory, version):
    root = directory / ('fixture-' + version)
    (root / 'DEBIAN').mkdir(parents=True)
    (root / 'etc').mkdir()
    (root / 'DEBIAN/control').write_text(
        'Package: pds-test-conffile\nVersion: ' + version + '\nArchitecture: all\n'
        'Maintainer: PDS package test\nDescription: Disposable conffile upgrade fixture\n')
    (root / 'DEBIAN/conffiles').write_text('/etc/pds-test-conffile.conf\n')
    (root / 'etc/pds-test-conffile.conf').write_text('vendor version ' + version + '\n')
    output = directory / ('pds-test-conffile_' + version + '_all.deb')
    command(['dpkg-deb', '--build', str(root), str(output)])
    return output


class ImageBaseline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Path('/.dockerenv').exists():
            raise RuntimeError('These root filesystem/service checks require a disposable container.')
        Path('/run/sshd').mkdir(exist_ok=True)
        command(['ssh-keygen', '-A'])

    def test_ssh_policy_overrides_cloud_init_without_reloading(self):
        paths = [Path('/etc/ssh/sshd_config'),
                 Path('/etc/ssh/sshd_config.d/00-pds-security.conf'),
                 Path('/etc/ssh/sshd_config.d/10-test-permissive.conf'),
                 Path('/etc/ssh/sshd_config.d/50-cloud-init.conf'),
                 Path('/root/.ssh/authorized_keys')]
        saved = {path: path.read_bytes() if path.exists() else None for path in paths}
        server = None
        try:
            paths[1].unlink(missing_ok=True)
            paths[2].write_text('PasswordAuthentication yes\nKbdInteractiveAuthentication yes\nPermitRootLogin yes\n')
            paths[3].write_text('PasswordAuthentication yes\n')
            command(['useradd', '-m', '-s', '/bin/bash', 'pds-ssh-test'])
            password = os.urandom(24).hex()
            command(['chpasswd'], input=f'pds-ssh-test:{password}\nroot:{password}\n')
            with tempfile.TemporaryDirectory() as tmp:
                key = Path(tmp) / 'key'
                command(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(key)])
                for home in (Path('/root'), Path('/home/pds-ssh-test')):
                    ssh = home / '.ssh'
                    ssh.mkdir(mode=0o700, exist_ok=True)
                    (ssh / 'authorized_keys').write_bytes(key.with_suffix('.pub').read_bytes())
                    (ssh / 'authorized_keys').chmod(0o600)
                command(['chown', '-R', 'pds-ssh-test:pds-ssh-test', '/home/pds-ssh-test/.ssh'])
                server = subprocess.Popen(['/usr/sbin/sshd', '-D', '-e', '-p', '2222',
                                           '-o', 'PidFile=/run/pds-test-sshd.pid'],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                for _ in range(100):
                    try:
                        with socket.create_connection(('127.0.0.1', 2222), timeout=0.05):
                            break
                    except OSError:
                        time.sleep(0.03)
                else:
                    self.fail('Owned test sshd did not start.')
                base = ['ssh', '-p', '2222', '-o', 'StrictHostKeyChecking=no',
                        '-o', 'UserKnownHostsFile=/dev/null', '-o', 'ConnectTimeout=3',
                        '-o', 'NumberOfPasswordPrompts=1']

                def login(user, method):
                    if method == 'publickey':
                        args = base + ['-o', 'BatchMode=yes', '-i', str(key)]
                    else:
                        args = ['sshpass', '-e'] + base + ['-o', 'PubkeyAuthentication=no',
                                                        '-o', 'PreferredAuthentications=' + method]
                    return command(args + [user + '@127.0.0.1', 'printf pds-auth-ok'],
                                   check=False, env={**os.environ, 'SSHPASS': password})

                # Positive controls make the negative tests capable of detecting bad policy.
                for user, method in [('root', 'publickey'), ('pds-ssh-test', 'password'),
                                     ('pds-ssh-test', 'keyboard-interactive')]:
                    result = login(user, method)
                    self.assertEqual(result.returncode, 0, result.stderr)
                marker = Path(tmp) / 'observed'
                pds('pds_before_ssh_policy() { printf applied >> ' + shlex.quote(str(marker)) +
                    '; }; restricted_ssh_security_profile; restricted_ssh_security_profile')
                self.assertEqual(marker.read_text(), 'appliedapplied')
                self.assertTrue(paths[1].is_file())
                effective = command(['/usr/sbin/sshd', '-T']).stdout
                for setting in ('passwordauthentication no', 'kbdinteractiveauthentication no',
                                'permitrootlogin no', 'pubkeyauthentication yes'):
                    self.assertIn(setting + '\n', effective)
                self.assertEqual(login('pds-ssh-test', 'password').returncode, 0,
                                 'Configuration helper must not reload a running daemon.')
                os.kill(server.pid, signal.SIGHUP)
                time.sleep(0.2)
                self.assertEqual(login('pds-ssh-test', 'publickey').returncode, 0)
                for user, method in [('root', 'publickey'), ('pds-ssh-test', 'password'),
                                     ('pds-ssh-test', 'keyboard-interactive')]:
                    result = login(user, method)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('Permission denied (publickey)', result.stderr)
        finally:
            if server:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
            for path, content in saved.items():
                if content is None:
                    path.unlink(missing_ok=True)
                else:
                    path.write_bytes(content)
            command(['userdel', '-r', 'pds-ssh-test'], check=False)

    def test_ssh_rejects_invalid_existing_configuration_without_mutation(self):
        main = Path('/etc/ssh/sshd_config')
        before = main.read_bytes()
        managed = Path('/etc/ssh/sshd_config.d/00-pds-security.conf')
        policy = managed.read_bytes() if managed.exists() else None
        invalid = before + b'\nPdsTestInvalidDirective yes\n'
        try:
            main.write_bytes(invalid)
            result = pds('restricted_ssh_security_profile', check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(main.read_bytes(), invalid)
            self.assertEqual(managed.read_bytes() if managed.exists() else None, policy)
        finally:
            main.write_bytes(before)

    def test_ssh_rolls_back_when_an_earlier_setting_overrides_the_policy(self):
        main = Path('/etc/ssh/sshd_config')
        managed = Path('/etc/ssh/sshd_config.d/00-pds-security.conf')
        original = main.read_bytes()
        old_policy = managed.read_bytes() if managed.exists() else None
        old_mode = managed.stat().st_mode & 0o777 if managed.exists() else None
        try:
            managed.write_bytes(b'# previous operator state\n')
            managed.chmod(0o600)
            main.write_bytes(b'PasswordAuthentication yes\n' + original)
            result = pds('restricted_ssh_security_profile', check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(managed.read_bytes(), b'# previous operator state\n')
            self.assertEqual(managed.stat().st_mode & 0o777, 0o600)
        finally:
            main.write_bytes(original)
            if old_policy is None:
                managed.unlink(missing_ok=True)
            else:
                managed.write_bytes(old_policy)
                managed.chmod(old_mode)

    def test_update_job_is_repeatable_and_handles_modified_conffiles(self):
        crontab = Path('/etc/crontab')
        original = crontab.read_text() if crontab.exists() else ''
        legacy = '0 0 * * * root apt update -y && apt upgrade -y'
        operator = '15 4 * * * root echo operator-job'
        crontab.write_text(original + '\n' + legacy + '\n' + operator + '\n')
        pds('update_system_cron_entry; update_system_cron_entry')
        self.assertNotIn(legacy, crontab.read_text())
        self.assertIn(operator, crontab.read_text())
        pds('source /work/bash/common/admin/sysadmin.sh; update_system_cron_entry')
        self.assertNotIn(legacy, crontab.read_text())
        cron = Path('/etc/cron.d/pds-update')
        jobs = [line for line in cron.read_text().splitlines()
                if line.strip() and not line.startswith('#') and '=' not in line]
        self.assertEqual(len(jobs), 1)
        fields = jobs[0].split(maxsplit=6)
        self.assertEqual(fields[:6], ['0', '0', '*', '*', '*', 'root'])
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            old, new = [fixture_package(directory, version) for version in ('1.0', '2.0')]
            command(['dpkg', '-i', str(old)])
            Path('/etc/pds-test-conffile.conf').write_text('operator configuration\n')
            try:
                with apt_repository([new]):
                    result = command(['/bin/sh', '-c', fields[6]], check=False,
                                     env={'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'HOME': '/root',
                                          'SHELL': '/bin/sh', 'LOGNAME': 'root'},
                                     input='', timeout=90)
                    self.assertEqual(result.returncode, 0, result.stderr)
                version = command(['dpkg-query', '-W', '-f=' + chr(36) + '{Version}',
                                   'pds-test-conffile']).stdout
                self.assertEqual(version, '2.0')
                self.assertEqual(Path('/etc/pds-test-conffile.conf').read_text(), 'operator configuration\n')
            finally:
                command(['dpkg', '--purge', 'pds-test-conffile'], check=False)

    def test_update_lock_contention_is_bounded_and_can_recover(self):
        pds('update_system_cron_entry')
        script = '/usr/local/sbin/pds-update'
        with apt_repository():
            for name in ['/var/lib/apt/lists/lock', '/var/lib/dpkg/lock-frontend']:
                with self.subTest(lock=name), open(name, 'w') as lock:
                    fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    start = time.monotonic()
                    result = command([script], env={**os.environ, 'PDS_UPDATE_LOCK_TIMEOUT': '1'},
                                     check=False, timeout=10)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('lock', (result.stdout + result.stderr).lower())
                    self.assertLess(time.monotonic() - start, 8)
            with open('/var/lib/apt/lists/lock', 'w') as lock:
                fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                release = threading.Timer(1.2, lambda: fcntl.lockf(lock, fcntl.LOCK_UN))
                release.start()
                try:
                    result = command([script], env={**os.environ, 'PDS_UPDATE_LOCK_TIMEOUT': '4'},
                                     check=False, timeout=15)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                finally:
                    release.cancel()


if __name__ == '__main__':
    unittest.main(verbosity=2)
