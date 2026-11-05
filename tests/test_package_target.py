"""Exercise the actual Make target with normalized prerelease filenames."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PackageTarget(unittest.TestCase):
    def run_target(self, filenames):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            packaging = root / 'packaging'
            (packaging / 'dist').mkdir(parents=True)
            shutil.copy2(ROOT / 'packaging/Makefile', packaging / 'Makefile')
            for filename in filenames:
                (packaging / 'dist' / filename).touch()
            tools = root / 'bin'
            tools.mkdir()
            docker = tools / 'docker'
            docker.write_text('''#!/bin/sh
set -eu
if [ "$1" = run ]; then
    for argument do
        case "$argument" in
            PDS_TEST_PACKAGE=*) package=${argument#PDS_TEST_PACKAGE=} ;;
        esac
    done
    printf '%s\\n' "$package" > "$TEST_PROJECT_ROOT/selected"
    test -f "$TEST_PROJECT_ROOT/${package#/work/}"
fi
''')
            docker.chmod(0o755)
            result = subprocess.run(['make', '-o', 'build', 'test-image-provisioning',
                                     'VERSION=0.20.0-PullRequest35.16'], cwd=packaging,
                                    env={**os.environ, 'PATH': f'{tools}:' + os.environ['PATH'],
                                         'TEST_PROJECT_ROOT': str(root)},
                                    text=True, capture_output=True, timeout=15)
            selected = root / 'selected'
            return result, selected.read_text().strip() if selected.exists() else None

    def test_uses_the_package_produced_by_nfpm(self):
        for filename in ('pds_1.0.0_all.deb', 'pds_0.20.0~PullRequest35.16_all.deb'):
            with self.subTest(filename=filename):
                result, selected = self.run_target([filename])
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(selected, '/work/packaging/dist/' + filename)

    def test_missing_or_ambiguous_package_does_not_run_container(self):
        for filenames in ([], ['pds_1.0.0_all.deb', 'pds_2.0.0_all.deb']):
            result, selected = self.run_target(filenames)
            self.assertNotEqual(result.returncode, 0)
            self.assertIsNone(selected)


if __name__ == '__main__':
    unittest.main()
