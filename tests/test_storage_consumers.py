"""Storage-consumer policy tests; native scenarios run only in disposable containers."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import unittest

import test_storage_maintenance as go_tests

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'bash/fedora/storage_consumers.sh'

CONSUMER_STUB = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
state = json.loads(Path(os.environ['PDS_TEST_STATE']).read_text())
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with Path(os.environ['PDS_TEST_LOG']).open('a') as log:
    log.write(json.dumps({'name': name, 'args': args,
                         'remote': os.environ.get('DOCKER_CONTEXT')}) + '\n')
if state.get('consumer_failure') == name:
    print('injected consumer failure: ' + name, file=sys.stderr)
    sys.exit(1)
if name == 'docker':
    if args[:2] != ['--host', 'unix:///var/run/docker.sock']:
        print('remote endpoint was not confined', file=sys.stderr)
        sys.exit(2)
    args = args[2:]
    if args[:2] == ['system', 'df']:
        if state.get('malformed_accounting'):
            print('not-json')
        else:
            for kind, size, count in [('Images', '46.95GB', '239'),
                                      ('Containers', '687MB', '69'),
                                      ('Local Volumes', '47.57GB', '118'),
                                      ('Build Cache', '121GB', '600')]:
                print(json.dumps({'Type': kind, 'Size': size,
                                  'Reclaimable': size, 'TotalCount': count, 'Active': '0'}))
    elif args[:2] == ['volume', 'ls']:
        print('\n'.join('volume-' + str(i) for i in range(109)))
    elif args[:2] not in (['buildx', 'prune'], ['image', 'prune']):
        print('unexpected docker operation: ' + repr(args), file=sys.stderr)
        sys.exit(2)
elif name == 'podman':
    if not args or args.pop(0) != '--remote=false':
        sys.exit(2)
    if args[:2] == ['system', 'df']:
        print(json.dumps([{'Type': 'Images', 'RawSize': 61000000000,
                           'RawReclaimable': 60000000000},
                          {'Type': 'Local Volumes', 'RawSize': 0, 'RawReclaimable': 0}]))
    elif args[:2] != ['image', 'prune']:
        sys.exit(2)
elif name == 'uv':
    if args == ['--version']:
        print(state.get('uv_version', 'uv 0.10.9'))
    elif 'prune' not in args:
        sys.exit(2)
elif name == 'npm':
    if 'verify' not in args:
        sys.exit(2)
else:
    sys.exit(2)
'''


class ConsumerTests(unittest.TestCase):
    commands = go_tests.StorageUnitTests.commands

    def setUp(self):
        go_tests.StorageUnitTests.setUp(self)
        (self.home / '.cache/uv').mkdir()
        (self.home / '.cache/uv/CACHEDIR.TAG').write_text(
            'Signature: 8a477f597d28d172789f06886806bc55')
        (self.home / '.npm').mkdir()
        (self.home / 'code/.cache/builders-active').mkdir(parents=True)
        (self.home / 'code/.triage-review-archive').mkdir()
        for name in ('docker', 'podman', 'uv', 'npm'):
            path = self.bin / name
            path.write_text(CONSUMER_STUB)
            path.chmod(0o755)
        self.environment.update(DOCKER_HOST='ssh://unrelated-host',
                                DOCKER_CONTEXT='remote-context',
                                BUILDX_BUILDER='remote-builder')

    def run_consumer(self, mode, root=False, **state):
        self.state.update(state)
        self.state['current_uid'] = 0 if root else 1000
        self.state_path.write_text(json.dumps(self.state))
        return subprocess.run(['bash', str(SCRIPT), mode, '--user', 'pds-test'],
                              env=self.environment, text=True, capture_output=True,
                              timeout=30)

    def test_ac09_only_fixed_local_cache_and_seven_day_image_prunes(self):
        result = self.run_consumer('cleanup-docker', root=True)
        self.assertIn(result.returncode, (0, 1), result.stdout + result.stderr)
        calls = [entry['args'][2:] for entry in self.commands('docker')]
        self.assertIn(['buildx', 'prune', '--builder', 'default', '--max-used-space',
                       '20000000000', '--reserved-space', '10000000000', '--force'], calls)
        self.assertIn(['image', 'prune', '--all', '--filter', 'until=168h', '--force'], calls)
        for args in calls:
            self.assertNotEqual(args[:2], ['volume', 'prune'])
            self.assertNotEqual(args[:2], ['system', 'prune'])
            self.assertNotEqual(args[:2], ['container', 'prune'])
        self.assertTrue(all(not call['remote'] for call in self.commands('docker')))

    def test_ac11_audit_warns_for_images_build_cache_and_volumes_without_pruning(self):
        result = self.run_consumer('audit-docker', root=True)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for expected in ('Images', 'Build Cache', 'Local Volumes', '109', 'WARN'):
            self.assertIn(expected, result.stdout)
        self.assertFalse(any('prune' in call['args'] for call in self.commands('docker')))

    def test_ac12_failed_prune_and_malformed_accounting_are_not_success(self):
        for state in ({'consumer_failure': 'docker'}, {'malformed_accounting': True}):
            with self.subTest(state=state):
                result = self.run_consumer('cleanup-docker', root=True, **state)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.state['consumer_failure'] = ''
                self.state['malformed_accounting'] = False

    def test_ac10_native_user_operations_do_not_prune_persistent_data(self):
        result = self.run_consumer('cleanup-user')
        self.assertIn(result.returncode, (0, 1), result.stdout + result.stderr)
        podman = [call['args'] for call in self.commands('podman')]
        self.assertIn(['--remote=false', 'image', 'prune', '--all',
                       '--filter', 'until=168h', '--force'], podman)
        self.assertTrue(any('verify' in call['args'] for call in self.commands('npm')))
        uv = [call['args'] for call in self.commands('uv') if 'prune' in call['args']]
        self.assertEqual(len(uv), 1)
        self.assertNotIn('--force', uv[0])
        self.assertNotIn('--ci', uv[0])
        self.assertIn('--offline', uv[0])
        self.assertEqual(self.module.read_text(), 'module data must remain')
        self.assertEqual(self.profile.read_text(), 'profile data must remain')

    def test_ac10_linked_uv_environments_and_unknown_versions_are_not_pruned(self):
        environments = self.home / '.cache/uv/environments-v2'
        environments.mkdir()
        marker = environments / 'project'
        marker.mkdir()
        (marker / 'keep').write_text('active environment')
        project = self.home / 'code/project'
        project.mkdir()
        (project / '.venv').symlink_to(marker, target_is_directory=True)
        for version in ('uv 0.10.9', 'uv 99.0.0'):
            with self.subTest(version=version):
                result = self.run_consumer('cleanup-user', uv_version=version)
                self.assertIn(result.returncode, (0, 1), result.stdout + result.stderr)
                self.assertIn('SKIP', result.stdout)
                self.assertEqual((project / '.venv/keep').read_text(), 'active environment')
        self.assertFalse(any('prune' in call['args'] for call in self.commands('uv')))

    def test_ac11_audit_preserves_worktrees_archives_and_shell_metacharacters(self):
        path = self.home / 'code/stackweaver-maintenance-$(touch SHOULD_NOT_EXIST)'
        path.mkdir()
        (path / 'source').write_text('unpushed')
        result = self.run_consumer('audit-user')
        self.assertIn(result.returncode, (0, 1, 2), result.stdout + result.stderr)
        self.assertIn('builders', result.stdout.lower())
        self.assertIn('review', result.stdout.lower())
        self.assertIn('modules', result.stdout.lower())
        self.assertIn('zed', result.stdout.lower())
        self.assertEqual((path / 'source').read_text(), 'unpushed')
        self.assertFalse((ROOT / 'SHOULD_NOT_EXIST').exists())
        self.assertFalse(any('prune' in call['args'] for call in self.commands('podman')))

    def test_ac12_sourcing_has_no_side_effects(self):
        command = f'set -eu; before=$-; source {shlex.quote(str(SCRIPT))}; test "$before" = "$-"'
        result = subprocess.run(['bash', '-c', command], capture_output=True, text=True,
                                env=self.environment, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
