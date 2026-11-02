"""Credential provisioning tests; use dummy data and never contact Cloudflare."""
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/common/cloud/bootstrap_cloudflared_host.sh"
CERTIFICATE = b"-----BEGIN ARGO TUNNEL TOKEN-----\ndummy-test-token\n-----END ARGO TUNNEL TOKEN-----\n"


class CertificateProvisioning(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.directory = self.home / ".cloudflared"
        self.certificate = self.directory / "cert.pem"
        self.environment = dict(os.environ, HOME=str(self.home))

    def receive(self, content=CERTIFICATE):
        return subprocess.run(
            ["bash", str(SCRIPT), "--receive-certificate"], input=content,
            env=self.environment, capture_output=True, check=False,
        )

    def test_private_permissions_and_no_credential_output(self):
        result = self.receive()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.certificate.read_bytes(), CERTIFICATE)
        self.assertEqual(stat.S_IMODE(self.directory.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.certificate.stat().st_mode), 0o600)
        self.assertNotIn(b"dummy-test-token", result.stdout + result.stderr)
        self.assertEqual(list(self.directory.iterdir()), [self.certificate])

    def test_repeated_setup_keeps_existing_certificate(self):
        self.assertEqual(self.receive().returncode, 0)
        inode = self.certificate.stat().st_ino
        self.assertEqual(self.receive().returncode, 0)
        self.assertEqual(self.certificate.stat().st_ino, inode)

    def test_different_certificate_is_preserved(self):
        self.assertEqual(self.receive().returncode, 0)
        result = self.receive(CERTIFICATE.replace(b"dummy-test-token", b"other-token"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.certificate.read_bytes(), CERTIFICATE)
        self.assertEqual(list(self.directory.iterdir()), [self.certificate])

    def test_rejects_empty_and_invalid_data(self):
        for content in [b"", b"not-a-certificate"]:
            with self.subTest(content=content):
                self.assertNotEqual(self.receive(content).returncode, 0)
                self.assertFalse(self.certificate.exists())
                self.assertEqual(list(self.directory.iterdir()), [])

    def test_does_not_follow_certificate_symlink(self):
        victim = self.home / "keep-me"
        victim.write_bytes(b"unchanged")
        self.directory.mkdir()
        self.certificate.symlink_to(victim)
        self.assertNotEqual(self.receive().returncode, 0)
        self.assertEqual(victim.read_bytes(), b"unchanged")

    def test_does_not_follow_directory_symlink(self):
        victim = self.home / "keep-directory"
        victim.mkdir()
        self.directory.symlink_to(victim, target_is_directory=True)
        self.assertNotEqual(self.receive().returncode, 0)
        self.assertEqual(list(victim.iterdir()), [])

    def test_remote_target_cannot_inject_shell_commands(self):
        source = self.home / "source.pem"
        source.write_bytes(CERTIFICATE)
        marker = self.home / "injected"
        result = subprocess.run(
            ["bash", str(SCRIPT), "--cert-file", str(source),
             "--ssh", f"host;touch {marker}"], env=self.environment,
            capture_output=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())

    def test_pds_can_source_library_without_running_bootstrap(self):
        result = subprocess.run(
            ["bash", "-c", 'before=$-; source "$1"; '
             '[[ $before == $- ]] || exit 1; '
             'declare -F bootstrap_cloudflared_host >/dev/null || exit 1; '
             'if declare -F main die prepare_host receive_certificate; then exit 1; fi',
             "test", str(SCRIPT)], env=self.environment,
            capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"")
        self.assertFalse(self.directory.exists())


if __name__ == "__main__":
    unittest.main()
