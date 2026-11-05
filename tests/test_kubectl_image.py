"""Installer contracts with controlled downloads; real network/boot proof is separate."""
import hashlib
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import tempfile
import unittest

LIB = Path('/usr/share/pds')


class KubectlImage(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Path('/.dockerenv').exists():
            raise RuntimeError('Run only inside the disposable package test container.')

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.root.chmod(0o755)
        self.home = self.root / 'home'
        self.home.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.calls = self.root / 'calls'
        self.module = self.root / 'debian/software/install_kubectl.sh'
        self.module.parent.mkdir(parents=True)
        shutil.copy2(LIB / 'debian/software/install_kubectl.sh', self.module)
        shutil.copytree(LIB / 'config', self.root / 'config')
        self.write_command('sudo', 'exec "$@"')
        self.write_command('apt', 'exit 0')
        self.write_command('apt-get', 'exit 0')
        self.write_command('gpg', '''out=''
while [ "$#" -gt 0 ]; do
    case "$1" in -o|--output) out=$2; shift 2;; *) shift;; esac
done
if [ -n "$out" ]; then cat > "$out"; else cat; fi''')
        self.write_command('kubectl', '''if [ "$1" = completion ]; then
    if [ \"$2\" = zsh ]; then echo '_kubectl() { :; }; compdef _kubectl kubectl'; else echo '__start_kubectl() { :; }'; fi
elif [ "$1" = krew ]; then shift; exec "$KREW_ROOT/bin/kubectl-krew" "$@"
else exit 0; fi''')
        bootstrap = self.root / 'krew-linux_amd64'
        bootstrap.write_text('''#!/bin/bash
set -eu
export KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
printf 'krew %s\\n' "$*" >> "$TEST_CALLS"
if [[ "$1" == install ]]; then
    [[ "${2:-}" != stern || "${TEST_FAIL_PLUGIN:-}" != stern ]] || exit 43
    mkdir -p "$KREW_ROOT/bin"
    if [[ "$2" == --manifest=* || "$2" == krew ]]; then
        cp "$0" "$KREW_ROOT/bin/kubectl-krew"
    elif [[ "$2" != krew ]]; then
        printf '#!/bin/sh\\nprintf "plugin %s\\\\n"\\n' "$2" > "$KREW_ROOT/bin/kubectl-$2"
        chmod 755 "$KREW_ROOT/bin/kubectl-$2"
    fi
fi
''')
        bootstrap.chmod(0o755)
        self.archive = self.root / 'archive.tar.gz'
        with tarfile.open(self.archive, 'w:gz') as archive:
            archive.add(bootstrap, arcname='./krew-linux_amd64')
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.root / 'config/krew-releases.sha256').write_text(
            f'{self.digest}  v0.5.0/krew-linux_amd64.tar.gz\n')
        self.write_command('curl', '''printf 'curl %s\\n' "$*" >> "$TEST_CALLS"
out='' remote=0 url=''
while [ "$#" -gt 0 ]; do
    case "$1" in -o) out=$2; shift 2;; -*O*) remote=1; shift;; https://*) url=$1; shift;; *) shift;; esac
done
if [ "$remote" = 1 ]; then out=${url##*/}; fi
if [ "${url##*/}" = krew-releases.sha256 ]; then cp "$TEST_PINS" "$out"; exit; fi
if [ -n "$out" ]; then cp "$TEST_ARCHIVE" "$out"; else echo fixture-key; fi''')
        self.pins = self.root / 'raw-pins.sha256'
        shutil.copy2(self.root / 'config/krew-releases.sha256', self.pins)
        self.env = {**os.environ, 'PATH': f'{self.bin}:/usr/sbin:/usr/bin:/sbin:/bin',
                    'HOME': str(self.home), 'SHELL': '/bin/bash',
                    'TEST_CALLS': str(self.calls), 'TEST_ARCHIVE': str(self.archive),
                    'TEST_PINS': str(self.pins)}
        self.env.pop('KREW_ROOT', None)
        shutil.rmtree('/usr/local/share/pds/krew', ignore_errors=True)
        for path in ('/etc/profile.d/pds-kubectl.sh', '/etc/bash_completion.d/pds-kubectl',
                     '/etc/bash.bashrc.d/pds-kubectl.sh'):
            Path(path).unlink(missing_ok=True)

    def write_command(self, name, body):
        command = self.bin / name
        command.write_text('#!/bin/sh\nset -eu\n' + body + '\n')
        command.chmod(0o755)

    def run_install(self, args='', extra='', env=None, shell='bash'):
        return subprocess.run(
            [shell, '-euc', f'source {shlex.quote(str(self.module))}; '
             f'install_kubectl 1.37 {args}; {extra or ":"}'],
            text=True, capture_output=True, timeout=20, env={**self.env, **(env or {})})

    def test_system_mode_exposes_tools_to_a_fresh_user(self):
        result = self.run_install('--system')
        self.assertEqual(result.returncode, 0, result.stderr)
        shared = Path('/usr/local/share/pds/krew')
        self.assertTrue((shared / 'bin/kubectl-krew').is_file())
        self.assertFalse((self.home / '.krew').exists())
        subprocess.run(['useradd', '-m', 'pds-kubectl-fresh'], check=True)
        try:
            script = 'source /etc/profile.d/pds-kubectl.sh; '
            script += '[[ "$KREW_ROOT" == /usr/local/share/pds/krew ]]; '
            script += 'for p in neat view-secret stern; do "kubectl-$p"; done; '
            script += '[[ ! -w "$KREW_ROOT" ]]; alias k'
            check = subprocess.run(['runuser', '-u', 'pds-kubectl-fresh', '--',
                                    'bash', '-euc', script], text=True, capture_output=True)
            self.assertEqual(check.returncode, 0, check.stderr)
            for name in ('neat', 'view-secret', 'stern'):
                self.assertIn(f'plugin {name}', check.stdout)
            self.assertTrue(Path('/etc/bash_completion.d/pds-kubectl').is_file())
            self.assertIn('/etc/profile.d/pds-kubectl.sh', Path('/etc/bash.bashrc').read_text())
        finally:
            subprocess.run(['userdel', '-r', 'pds-kubectl-fresh'], capture_output=True)

    def test_normal_install_stays_per_user_and_is_repeatable(self):
        for _ in range(2):
            result = self.run_install()
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / '.krew/bin/kubectl-krew').is_file())
        self.assertFalse(Path('/usr/local/share/pds/krew').exists())
        profile = (self.home / '.bashrc').read_text()
        self.assertEqual(profile.count('alias k=kubectl'), 1)
        self.assertNotIn(str(self.home), profile)

    def test_normal_install_overrides_inherited_shared_root(self):
        for shell_name in ('bash', 'zsh'):
            with self.subTest(shell=shell_name):
                env = {'KREW_ROOT': '/usr/local/share/pds/krew',
                       'SHELL': '/usr/bin/' + shell_name}
                for _ in range(2):
                    result = self.run_install(env=env, shell=shell_name)
                    self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((self.home / '.krew/bin/kubectl-krew').is_file())
                self.assertFalse(Path('/usr/local/share/pds/krew').exists())
                profile = self.home / ('.' + shell_name + 'rc')
                script = ('autoload -Uz compinit; compinit -D; ' if shell_name == 'zsh' else '')
                script += f'source {shlex.quote(str(profile))}; '
                script += 'test "$KREW_ROOT" = "$HOME/.krew"; kubectl-neat'
                result = subprocess.run([shell_name, '-fc', script],
                                        env={**self.env, **env}, text=True,
                                        capture_output=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('plugin neat', result.stdout)

    def test_normal_install_preserves_custom_root_in_fresh_shell(self):
        custom = self.home / 'custom krew'
        result = self.run_install(env={'KREW_ROOT': str(custom)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((custom / 'bin/kubectl-krew').is_file())
        # A later shell must select the same explicit custom location.
        result = subprocess.run(['bash', '-euc',
                                 'source "$HOME/.bashrc"; kubectl-neat'],
                                env=self.env, text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('plugin neat', result.stdout)

    def test_zsh_alias_uses_the_generated_completion(self):
        # Model kubectl's Zsh output, including its registered function name.
        zi = Path('/usr/local/share/zi/zi.zsh')
        zi.parent.mkdir(parents=True, exist_ok=True)
        prior = zi.read_bytes() if zi.exists() else None
        zi.write_text('zi() { :; }; autoload -Uz compinit; compinit -D\n')
        try:
            command = 'source ' + shlex.quote(str(self.root / 'config/zshrc'))
            command += '; [[ ${_comps[kubectl]:-} == _kubectl && ${_comps[k]:-} == _kubectl ]]'
            result = subprocess.run(['zsh', '-dfc', command], env=self.env,
                                    text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            installed = self.run_install(env={'SHELL': '/usr/bin/zsh'})
            self.assertEqual(installed.returncode, 0, installed.stderr)
            profile = (self.home / '.zshrc').read_text()
            result = subprocess.run(['zsh', '-dfc',
                                     'autoload -Uz compinit; compinit -D; ' + profile +
                                     '; [[ ${_comps[k]:-} == _kubectl ]]'],
                                    env=self.env, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        finally:
            if prior is None:
                zi.unlink(missing_ok=True)
            else:
                zi.write_bytes(prior)

    def test_raw_workstation_fetches_pins_only_when_called(self):
        shutil.rmtree(self.root / 'config')
        loaded = subprocess.run(['bash', '-euc', f'source {shlex.quote(str(self.module))}'],
                                env=self.env, text=True, capture_output=True, timeout=20)
        self.assertEqual(loaded.returncode, 0, loaded.stderr)
        self.assertFalse(self.calls.exists())
        result = self.run_install(env={'PDS_REF': 'owned-test-ref'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('/owned-test-ref/bash/config/krew-releases.sha256', self.calls.read_text())
        self.assertTrue((self.home / '.krew/bin/kubectl-krew').is_file())

    def test_plugin_failure_stops_even_when_caller_checks_status(self):
        result = subprocess.run(['bash', '-euc',
                                 f'source {shlex.quote(str(self.module))}; '
                                 'if install_kubectl 1.37 --system; then exit 99; else exit 42; fi'],
                                env={**self.env, 'TEST_FAIL_PLUGIN': 'stern', 'ZSH_VERSION': ''},
                                text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertIn('stern', self.calls.read_text())

    def test_checksum_failure_prevents_extraction_and_execution(self):
        (self.root / 'config/krew-releases.sha256').write_text(
            f'{"0" * 64}  v0.5.0/krew-linux_amd64.tar.gz\n')
        result = self.run_install('--system')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('krew install', self.calls.read_text())

    def test_bad_inputs_do_not_install_anything(self):
        for args in ('1.37 --unknown', 'invalid --system', '1.37 --system extra'):
            result = subprocess.run(['bash', '-euc',
                                     f'source {shlex.quote(str(self.module))}; install_kubectl {args}'],
                                    env=self.env, text=True, capture_output=True, timeout=20)
            self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.calls.exists())


if __name__ == '__main__':
    unittest.main()
