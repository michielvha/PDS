"""Package and provisioning checks. Run only in the disposable test container."""
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIB = Path('/usr/share/pds')


def shell(script, *, env=None, check=True):
    return subprocess.run(['bash', '-euc', script], text=True, input='',
                          capture_output=True, timeout=20, check=check,
                          env={**os.environ, **(env or {})})


class ImageProvisioning(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Path('/.dockerenv').exists():
            raise RuntimeError('Run with make -C packaging test-image-provisioning; never on the host.')
        if not (LIB / 'init.sh').exists():
            raise RuntimeError('Install the built .deb before running these checks.')

    def test_strict_load_does_not_run_installers(self):
        with tempfile.TemporaryDirectory() as tmp:
            deny = Path(tmp)
            for name in ('sudo', 'curl', 'wget', 'git', 'apt', 'apt-get', 'dnf', 'systemctl'):
                p = deny / name
                p.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$PDS_TEST_CALLS"\nexit 91\n')
                p.chmod(0o755)
            calls = deny / 'calls'
            result = shell('source /usr/share/pds/init.sh; '
                           'declare -F install_zi configure_zsh setup_motd install_kubectl install_gh '
                           'restricted_ssh_security_profile set_sudo_nopasswd >/dev/null',
                           env={'PATH': f'{deny}:/usr/bin:/bin', 'PDS_TEST_CALLS': str(calls)},
                           check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(calls.exists(), calls.read_text() if calls.exists() else '')

    def test_load_failure_is_visible_and_keeps_caller_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            library = Path(tmp) / 'common/test'
            library.mkdir(parents=True)
            (library / 'broken.sh').write_text('return 7\n')
            result = shell('source /usr/share/pds/init.sh',
                           env={'PDS_LIB_DIR': tmp}, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Failed to load PDS library file', result.stderr)
        result = shell('before="$-"; PDS_LIB_DIR=/usr/share/pds; '
                       'source /usr/share/pds/init.sh; '
                       '[[ "$before" == "$-" && "$PDS_LIB_DIR" == /usr/share/pds ]]')
        self.assertEqual(result.returncode, 0)

    def test_zsh_load_keeps_options_and_does_not_run_installers(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            calls = directory / 'calls'
            for name in ('sudo', 'curl', 'wget', 'git', 'apt', 'apt-get', 'dnf', 'systemctl'):
                command = directory / name
                command.write_text('#!/bin/sh\nprintf "%s\\n" "$0" >> "$PDS_TEST_CALLS"\nexit 91\n')
                command.chmod(0o755)
            script = 'before=$(setopt); source /usr/share/pds/init.sh || exit; '
            script += '[[ "$before" == "$(setopt)" ]] || exit 92; '
            script += 'for fn in configure_zsh setup_motd install_kubectl install_azcli '
            script += 'update_system_cron_entry restricted_ssh_security_profile; '
            script += 'do (( $+functions[$fn] )) || exit 93; done'
            result = subprocess.run(['zsh', '-dfc', script], text=True,
                                    capture_output=True, timeout=20,
                                    env={**os.environ, 'PATH': f'{tmp}:/usr/bin:/bin',
                                         'PDS_TEST_CALLS': str(calls)})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertFalse(calls.exists(), calls.read_text() if calls.exists() else '')

    def test_zsh_reports_broken_and_empty_libraries(self):
        with tempfile.TemporaryDirectory() as tmp:
            for broken in (False, True):
                if broken:
                    module = Path(tmp) / 'common/test/broken.sh'
                    module.parent.mkdir(parents=True)
                    module.write_text('return 7\n')
                result = subprocess.run(['zsh', '-dfc', 'source /usr/share/pds/init.sh'],
                                        text=True, capture_output=True, timeout=20,
                                        env={**os.environ, 'PDS_LIB_DIR': tmp})
                self.assertEqual(result.returncode == 0, not broken, result.stderr)
                if broken:
                    self.assertIn('Failed to load PDS library file', result.stderr)

    def test_zsh_can_configure_from_packaged_assets_without_downloads(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = ('source /usr/share/pds/init.sh || exit; '
                      'curl() { return 91; }; configure_zsh || exit; '
                      'cmp "$HOME/.p10k.zsh" /usr/share/pds/config/.p10k.zsh')
            result = subprocess.run(['zsh', '-dfc', script], text=True,
                                    capture_output=True, timeout=20,
                                    env={**os.environ, 'HOME': tmp})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_zsh_uses_existing_preset_and_zi(self):
        expected = (ROOT / 'bash/config/.p10k.zsh').read_bytes()
        self.assertEqual((LIB / 'config/.p10k.zsh').read_bytes(), expected)
        Path.home().joinpath('.p10k.zsh').write_text('# personal preset\n')
        shell('source /usr/share/pds/init.sh; configure_zsh; configure_zsh')
        self.assertEqual(Path('/etc/skel/.p10k.zsh').read_bytes(), expected)
        self.assertEqual(Path.home().joinpath('.p10k.zsh').read_bytes(), expected)
        self.assertEqual(Path.home().joinpath('.p10k.zsh.pds-backup').read_text(),
                         '# personal preset\n')
        shell('useradd -m pds-clone-test')
        self.assertEqual(Path('/home/pds-clone-test/.p10k.zsh').read_bytes(), expected)
        config = Path('/etc/zshrc').read_text()
        self.assertIn('zi light romkatv/powerlevel10k', config)
        self.assertIn('zi light michielvha/zsh-readline', config)
        self.assertNotIn('oh-my-zsh.sh', config)
        shell('mkdir -p /usr/local/share/zi')
        Path('/usr/local/share/zi/zi.zsh').write_text(
            'zi() { printf "%s\\n" "$*" >> /tmp/pds-zi-requests; }\n')
        result = subprocess.run(['zsh', '-dfc', 'source /etc/zshrc'],
                                text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('light romkatv/powerlevel10k', Path('/tmp/pds-zi-requests').read_text())

    def test_zi_install_is_repeatable(self):
        shell('rm -rf /usr/local/share/zi')
        with tempfile.TemporaryDirectory() as tmp:
            git = Path(tmp) / 'git'
            git.write_text('#!/bin/bash\nset -eu\n'
                           'printf "%s\\n" "$*" >> "$PDS_TEST_GIT_CALLS"\n'
                           'if [[ "$1" == clone ]]; then mkdir -p "${@: -1}"; '
                           'touch "${@: -1}/zi.zsh"; fi\n')
            git.chmod(0o755)
            calls = Path(tmp) / 'calls'
            result = shell('sudo() { "$@"; }; source /usr/share/pds/init.sh; install_zi; install_zi',
                           env={'PATH': f'{tmp}:/usr/bin:/bin', 'PDS_TEST_GIT_CALLS': str(calls)},
                           check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(calls.read_text().splitlines()), 1)

    def test_motd_manages_only_its_own_script(self):
        vendor = Path('/etc/update-motd.d/00-vendor-test')
        vendor.parent.mkdir(exist_ok=True)
        vendor.write_text('#!/bin/sh\necho vendor\n')
        with tempfile.TemporaryDirectory() as tmp:
            banner = Path(tmp) / 'banner'
            banner.write_text('My homelab\n')
            shell(f'source /usr/share/pds/init.sh; setup_motd {shlex.quote(str(banner))}; '
                  f'setup_motd {shlex.quote(str(banner))}')
            managed = Path('/etc/update-motd.d/90-pds')
            result = shell(str(managed))
            self.assertEqual(result.stdout, 'My homelab\n')
            self.assertEqual(vendor.read_text(), '#!/bin/sh\necho vendor\n')
            self.assertEqual(managed.stat().st_mode & 0o777, 0o755)
            before = hashlib.sha256(managed.read_bytes()).hexdigest()
            result = shell('source /usr/share/pds/init.sh; setup_motd /does-not-exist', check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(hashlib.sha256(managed.read_bytes()).hexdigest(), before)

    def test_standalone_shell_fetches_assets_only_when_configuring(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            module = directory / 'zsh.sh'
            module.write_bytes((ROOT / 'bash/common/shell/zsh.sh').read_bytes())
            curl = directory / 'curl'
            curl.write_text('#!/bin/bash\nset -eu\n'
                            'printf "%s\\n" "$2" >> "$PDS_TEST_FETCHES"\n'
                            'cp "/usr/share/pds/config/${2##*/}" "$4"\n')
            curl.chmod(0o755)
            calls = directory / 'calls'
            shell(f'source {shlex.quote(str(module))}; '
                  'test ! -e "$PDS_TEST_FETCHES"; configure_zsh',
                  env={'PATH': f'{tmp}:/usr/bin:/bin',
                       'PDS_REF': 'test-ref', 'PDS_TEST_FETCHES': str(calls)})
            self.assertEqual(len(calls.read_text().splitlines()), 2)
            self.assertIn('/test-ref/bash/config/.p10k.zsh', calls.read_text())

    def test_zsh_configuration_cleans_temporary_assets_on_failure(self):
        for shell_name in ('bash', 'zsh'):
            with self.subTest(shell=shell_name), tempfile.TemporaryDirectory() as tmp:
                directory = Path(tmp)
                module = directory / 'zsh.sh'
                module.write_bytes((LIB / 'common/shell/zsh.sh').read_bytes())
                work = directory / 'work'
                work.mkdir()
                script = 'trap "printf caller-exit" EXIT; '
                script += f'source {shlex.quote(str(module))}; curl() {{ return 41; }}; '
                script += 'if configure_zsh; then exit 99; fi; '
                script += 'test -z "$(ls -A "$TMPDIR")"'
                result = subprocess.run([shell_name, '-euc', script], text=True,
                                        capture_output=True, timeout=20,
                                        env={**os.environ, 'HOME': tmp, 'TMPDIR': str(work)})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, 'caller-exit')

    def test_bash_stdin_import_reports_missing_library(self):
        # Stdin has no source filename; report the unsupported import clearly.
        code = (LIB / 'common/cloud/azure.sh').read_text() + '\nprintf continued\n'
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(['bash'], input=code, cwd=tmp,
                                    text=True, capture_output=True, timeout=20)
        self.assertEqual(result.stdout, 'continued')
        self.assertIn('No such file or directory', result.stderr)
        self.assertNotIn('bad substitution', result.stderr)

    def test_cli_discovers_the_packaged_helpers(self):
        self.assertIn('install_zi', shell('pds help').stdout)
        self.assertNotIn('install_ohmyzsh', shell('pds help').stdout)
        self.assertIn('setup_motd()', shell('pds show setup_motd').stdout)
        shell('pds doctor')

    def test_sudoers_uses_validated_canonical_function(self):
        shell('id pds-test >/dev/null 2>&1 || useradd pds-test; '
              'source /usr/share/pds/init.sh; set_sudo_nopasswd pds-test; '
              'visudo -cf /etc/sudoers.d/pds-test >/dev/null')
        self.assertEqual(Path('/etc/sudoers.d/pds-test').stat().st_mode & 0o777, 0o440)
        shell('source /work/bash/module/sysadmin.sh; '
              'declare -f set_sudo_nopasswd | grep -q visudo')

    def test_azure_compatibility_import_uses_canonical_installer(self):
        canonical = shell('source /work/bash/debian/software/install_azcli.sh; '
                          'declare -f install_azcli').stdout
        compatibility = shell('source /work/bash/common/cloud/azure.sh; '
                              'declare -f install_azcli').stdout
        self.assertEqual(compatibility, canonical)


if __name__ == '__main__':
    unittest.main(verbosity=2)
