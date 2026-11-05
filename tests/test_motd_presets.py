"""MOTD preset tests; run only in the disposable PDS test container."""
import hashlib
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(script, check=True):
    return subprocess.run(['bash', '-euc', 'source /usr/share/pds/init.sh; ' + script],
                          text=True, capture_output=True, timeout=20, check=check)


class MotdPresets(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Path('/.dockerenv').exists():
            raise RuntimeError('Disposable container required.')
        Path('/etc/update-motd.d').mkdir(parents=True, exist_ok=True)

    def test_all_presets_are_packaged_and_switch_repeatably(self):
        vendor = Path('/etc/update-motd.d/01-test-vendor')
        vendor.write_text('#!/bin/sh\necho vendor\n')
        for name in ('vhco', 'stackweaver', 'edgeforge', 'vhco'):
            with self.subTest(name=name):
                expected = (ROOT / 'bash/config/motd' / (name + '.txt')).read_bytes()
                installed = Path('/usr/share/pds/config/motd') / (name + '.txt')
                self.assertEqual(installed.read_bytes(), expected)
                run('setup_motd_preset ' + name + '; setup_motd_preset ' + name)
                self.assertEqual(Path('/etc/pds/motd-banner').read_bytes(), expected)
                output = subprocess.run(['/etc/update-motd.d/90-pds'], capture_output=True, check=True)
                self.assertEqual(output.stdout, expected)
                self.assertEqual(vendor.read_text(), '#!/bin/sh\necho vendor\n')

    def test_edgeforge_preserves_the_legacy_plain_banner(self):
        # Recorded from the earlier builders banner; ignore trailing whitespace.
        banner = (ROOT / 'bash/config/motd/edgeforge.txt').read_text()
        normalized = '\n'.join(line.rstrip() for line in banner.splitlines()).rstrip()
        self.assertEqual(hashlib.sha256(normalized.encode()).hexdigest(),
                         'd68d3c897297bdf790ec91ad70c8519652fdeea39fc40acbb4e3cac3c2dd6228')

    def test_invalid_selection_preserves_active_banner_and_script(self):
        run('setup_motd_preset vhco')
        paths = [Path('/etc/pds/motd-banner'), Path('/etc/update-motd.d/90-pds')]
        before = [p.read_bytes() for p in paths]
        for arg in ('missing-preset', '../vhco', '/etc/passwd', '', 'vhco.txt'):
            result = run('setup_motd_preset ' + shlex.quote(arg), check=False)
            self.assertNotEqual(result.returncode, 0, arg)
            self.assertEqual([p.read_bytes() for p in paths], before)
        result = run('setup_motd_preset vhco invalid-information-tool', check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([p.read_bytes() for p in paths], before)

    def test_custom_file_is_data_and_standalone_checkout_resolves_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            banner = Path(tmp) / 'my banner.txt'
            banner.write_text('$(touch /tmp/pds-motd-must-not-execute)\n')
            run('setup_motd ' + shlex.quote(str(banner)))
            self.assertFalse(Path('/tmp/pds-motd-must-not-execute').exists())
            self.assertEqual(Path('/etc/pds/motd-banner').read_bytes(), banner.read_bytes())
        run('source /work/bash/debian/admin/setup_motd.sh; setup_motd_preset edgeforge')
        self.assertEqual(Path('/etc/pds/motd-banner').read_bytes(),
                         (ROOT / 'bash/config/motd/edgeforge.txt').read_bytes())


if __name__ == '__main__':
    unittest.main(verbosity=2)
