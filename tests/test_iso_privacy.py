"""Exercise the source/privacy boundary with real Git trees and fake secrets."""
import contextlib
import getpass
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import iso_privacy
import iso_tools
from nixos_tools import SafetyError


class PrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir='/tmp')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo'; self.repo.mkdir()
        (self.repo / 'iso-configs').mkdir()
        (self.repo / 'README.md').write_text('Public manual\n')
        (self.repo / 'flake.nix').write_text('{}\n')
        (self.repo / 'flake.lock').write_text(json.dumps({'nodes': {'root': {}}, 'root': 'root', 'version': 7}))
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        self.stage()

    def stage(self):
        subprocess.run(['git', '-C', str(self.repo), 'add', '-A'], check=True)

    def write(self, name, contents):
        path = self.repo / name; path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(contents); self.stage()
        return path

    def test_snapshot_never_reads_untracked_or_home_secrets_or_git_history(self):
        personal = self.base / 'home/.ssh/id_ed25519'; personal.parent.mkdir(parents=True)
        personal.write_text('private fixture outside repository')
        untracked = self.repo / 'personal-notes.txt'; untracked.write_text('untracked fixture')
        (self.repo / '.env').write_text('API_TOKEN=untracked-fixture')
        report = iso_privacy.snapshot(self.repo, self.base / 'snapshot')
        names = {item['path'] for item in report['files']}
        self.assertEqual(names, {'README.md', 'flake.nix', 'flake.lock'})
        self.assertFalse((self.base / 'snapshot/.git').exists())
        self.assertFalse((self.base / 'snapshot/.env').exists())

    def test_internal_tracked_alias_is_materialized_but_external_link_is_refused(self):
        cursor = self.write('assets/cursor', b'public cursor bytes')
        alias = self.repo / 'assets/alias'; alias.symlink_to('cursor'); self.stage()
        iso_privacy.snapshot(self.repo, self.base / 'snapshot')
        self.assertFalse((self.base / 'snapshot/assets/alias').is_symlink())
        self.assertEqual((self.base / 'snapshot/assets/alias').read_bytes(), cursor.read_bytes())
        alias.unlink(); alias.symlink_to(self.base / 'outside-key')
        (self.base / 'outside-key').write_text('outside secret fixture')
        with self.assertRaises(SafetyError) as error:
            iso_privacy.inspect_source(self.repo)
        self.assertNotIn('outside secret fixture', str(error.exception))

    def test_private_key_body_causes_failure_before_snapshot_creation(self):
        private = b'-----BEGIN ' + b'OPENSSH PRIVATE KEY-----\nprivate-fixture-body\n'
        self.write('hosts/laptop/innocent.nix', private)
        with self.assertRaises(SafetyError) as error:
            iso_privacy.snapshot(self.repo, self.base / 'snapshot')
        self.assertIn('innocent.nix', str(error.exception))
        self.assertNotIn('private-fixture-body', str(error.exception))
        self.assertFalse((self.base / 'snapshot').exists())

    def test_credential_paths_hash_literals_and_known_tokens_are_refused(self):
        examples = [('.ssh/id_ed25519', b'fixture'), ('secrets/passwords.yaml', b'fixture'),
                    ('hosts/x/credentials.key', b'fixture'), ('modules/public.nix', b'$6$salt$' + b'a' * 86),
                    ('scripts/value.py', b'ghp_' + b'A' * 40)]
        for number, (name, data) in enumerate(examples):
            with self.subTest(name=name):
                path = self.write(name, data)
                with self.assertRaises(SafetyError):
                    iso_privacy.inspect_source(self.repo)
                path.unlink(); self.stage()

    def test_private_urls_and_local_path_inputs_are_refused(self):
        for locked in [{'type': 'path', 'path': '/home/fixture/private'},
                       {'type': 'git', 'url': 'https://' + 'fixture-token@' + 'example.invalid/repo'}]:
            with self.subTest(locked=locked):
                self.write('flake.lock', json.dumps({'nodes': {'input': {'locked': locked}}}).encode())
                with self.assertRaises(SafetyError) as error:
                    iso_privacy.inspect_source(self.repo)
                self.assertNotIn('fixture-token', str(error.exception))

    def test_discovery_uses_a_sanitized_snapshot_and_actual_host_names(self):
        calls = []
        def fake_run(args, **kwargs):
            calls.append(list(map(str, args)))
            reference = next(a for a in args if str(a).startswith('path:'))
            public = Path(str(reference).split('#')[0][5:])
            self.assertTrue((public / 'README.md').is_file())
            self.assertFalse((public / '.git').exists())
            return json.dumps(['nix-laptop', 'nix-max'])
        with patch.object(iso_tools, 'need_tools'), patch.object(iso_tools, 'run', side_effect=fake_run):
            self.assertEqual(iso_tools.available_hosts(self.repo), ['nix-laptop', 'nix-max'])
        self.assertIn('--no-update-lock-file', calls[0])

    def test_host_wizard_writes_only_public_choices(self):
        output, errors = io.StringIO(), io.StringIO()
        meta = {'system': 'x86_64-linux', 'users': ['owner'], 'defaultUser': 'owner', 'desktop': 'hyprland'}
        with patch.object(iso_tools, 'REPO', self.repo), patch.object(iso_tools.os, 'geteuid', return_value=1000), \
             patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), \
             patch.object(iso_tools, 'available_hosts', return_value=['nix-laptop', 'nix-max']), \
             patch.object(iso_tools, 'host_metadata', return_value=meta), \
             patch.object(iso_tools, 'need_tools'), patch.object(iso_tools, 'run'), \
             patch('builtins.input', side_effect=['travel', 'nix-max', 'fresh']), \
             contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            result = iso_tools.main(['--configure-only'])
        self.assertEqual(result, 0, errors.getvalue())
        profile = (self.repo / 'iso-configs/travel.nix').read_text()
        for fragment in ['sourceHost = "nix-max"', 'sourceUser = "owner"', 'liveUsername = "fresh"']:
            self.assertIn(fragment, profile)
        self.assertNotIn('passwordHash', profile)

    def test_unknown_host_stops_before_writing_profile(self):
        with patch.object(iso_tools, 'REPO', self.repo), \
             patch.object(iso_tools, 'available_hosts', return_value=['nix-laptop']), \
             contextlib.redirect_stderr(io.StringIO()):
            result = iso_tools.main(['--name', 'travel', '--username', 'fresh', '--host', 'missing', '--dry-run'])
        self.assertEqual(result, 1)
        self.assertFalse((self.repo / 'iso-configs/travel.nix').exists())

    def test_password_is_hidden_hashed_through_stdin_and_never_printed(self):
        output = io.StringIO(); secret = 'temporary-fixture-password'
        with patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), patch.object(iso_tools, 'need_tools'), \
             patch.object(iso_tools.getpass, 'getpass', side_effect=[secret, secret]), \
             patch.object(iso_tools.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='$y$j9T$salt$fixture', stderr='')) as process, \
             contextlib.redirect_stdout(output):
            hashed = iso_tools.password_hash()
        self.assertTrue(hashed.startswith('$y$'))
        self.assertNotIn(secret, output.getvalue())
        self.assertNotIn(secret, repr(process.call_args.args))
        self.assertEqual(process.call_args.kwargs['input'], secret + '\n')
        self.assertNotIn('env', process.call_args.kwargs)

    def test_password_without_echo_free_terminal_is_refused(self):
        with patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), patch.object(iso_tools, 'need_tools'), \
             patch.object(iso_tools.getpass, 'getpass', side_effect=getpass.GetPassWarning('fixture')), \
             contextlib.redirect_stdout(io.StringIO()), self.assertRaises(SafetyError):
            iso_tools.password_hash()

    def test_preview_never_collects_password(self):
        with patch.object(iso_tools, 'REPO', self.repo), patch.object(iso_tools, 'password_hash') as collect, \
             contextlib.redirect_stdout(io.StringIO()):
            result = iso_tools.main(['--name', 'preview', '--username', 'fresh', '--password-mode', 'build', '--dry-run'])
        self.assertEqual(result, 0)
        collect.assert_not_called()
        self.assertFalse((self.repo / 'iso-configs/preview.nix').exists())

    def test_private_wrapper_keeps_hash_out_of_public_snapshot_and_pins_inputs(self):
        public = self.base / 'public'; iso_privacy.snapshot(self.repo, public)
        work = self.base / 'work'; work.mkdir()
        def lock(args, **kwargs):
            private = Path(args[-1]); (private / 'flake.lock').write_text((public / 'flake.lock').read_text())
        hashed = '$y$j9T$salt$fixture'
        with patch.object(iso_tools, 'run', side_effect=lock):
            reference = iso_tools.preset_wrapper(public, work, 'travel', hashed)
        private = work / 'private-build'
        self.assertEqual(stat.S_IMODE((private / 'password.hash').stat().st_mode), 0o600)
        self.assertEqual((private / 'password.hash').read_text(), hashed)
        self.assertNotIn(hashed, (private / 'flake.nix').read_text())
        self.assertFalse((public / 'password.hash').exists())
        self.assertNotIn('--impure', reference)


if __name__ == '__main__': unittest.main()
