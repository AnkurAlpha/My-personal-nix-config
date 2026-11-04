"""ISO orchestration, portable account and single-manual safety checks."""
import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import iso_tools
from nixos_tools import SafetyError


class IsoTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo'
        (self.repo / 'iso-configs').mkdir(parents=True)

    def test_profile_username_validation_and_injection(self):
        for username in ['alice', 'bob-user', 'nixos']:
            data = iso_tools.render_profile('travel', username, 'hyprland')
            self.assertIn(f'liveUsername = "{username}"', data)
            self.assertNotIn('ankur', data)
            self.assertNotIn('Password =', data)
        for username in ['root', 'a;id', 'a";throw', '${readFile}', '../x']:
            with self.subTest(username=username), self.assertRaises(SafetyError):
                iso_tools.render_profile('travel', username, 'minimal')
        for name in ['../travel', 'iso-test', '-bad', 'Bad', 'a;id']:
            with self.subTest(name=name), self.assertRaises(SafetyError):
                iso_tools.render_profile(name, 'alice', 'minimal')

    def test_create_idempotence_and_overwrite_protection(self):
        path = iso_tools.configure(self.repo, 'travel', 'alice', 'minimal')
        self.assertEqual(path, iso_tools.configure(self.repo, 'travel', 'alice', 'minimal'))
        with self.assertRaises(SafetyError):
            iso_tools.configure(self.repo, 'travel', 'bob', 'minimal')
        self.assertIn('alice', path.read_text())

    def test_underscore_profile_is_created_and_built_with_exact_name(self):
        profile = iso_tools.configure(self.repo, 'my_iso', 'garuda', 'hyprland')
        self.assertEqual(profile.name, 'my_iso.nix')
        commands = []
        def fake_run(command, **kwargs):
            args = list(map(str, command)); commands.append(args)
            link = Path(args[args.index('--out-link') + 1])
            (link / 'iso').mkdir(parents=True)
            (link / 'iso/test.iso').write_bytes(b'not a bootable ISO')
            return ''
        with patch.object(iso_tools, 'run', side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()):
            iso = iso_tools.build(self.repo, 'my_iso', self.base / 'out')
        self.assertTrue(iso.is_file())
        self.assertIn('#nixosConfigurations.iso-my_iso.config.system.build.isoImage', commands[0][-1])

    def test_wizard_retries_invalid_fields_before_staging(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        # Includes the reported my_iso / garuda / garuda sequence, then corrects the desktop.
        answers = ['../escape', 'my_iso', 'root', 'garuda', 'garuda', 'hyprland']
        with patch.object(iso_tools, 'REPO', self.repo), patch.object(iso_tools.os, 'geteuid', return_value=1000), \
             patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input', side_effect=answers) as prompt, \
             patch.object(iso_tools, 'need_tools'), patch.object(iso_tools, 'run') as command, \
             patch.object(iso_tools, 'build') as build, \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            status = iso_tools.main(['--configure-only'])
        self.assertEqual(status, 0, stderr.getvalue())
        self.assertEqual(prompt.call_count, len(answers))
        command.assert_called_once_with(['git', 'add', '--', 'iso-configs/my_iso.nix'], cwd=self.repo)
        build.assert_not_called()
        profile = (self.repo / 'iso-configs/my_iso.nix').read_text()
        self.assertIn('liveUsername = "garuda"', profile)
        self.assertIn('desktop = "hyprland"', profile)
        self.assertEqual(stderr.getvalue().count('Invalid choice:'), 3)
        self.assertIn('Garuda is a Linux distribution', stderr.getvalue())

    def test_wizard_accepts_desktop_menu_names_numbers_and_default(self):
        for choice, expected in [('1', 'hyprland'), ('2', 'minimal'), ('Hyprland', 'hyprland'), ('', 'hyprland')]:
            with self.subTest(choice=choice):
                stdout, stderr = io.StringIO(), io.StringIO()
                with patch.object(iso_tools, 'REPO', self.repo), \
                     patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), \
                     patch('builtins.input', side_effect=['my_iso', 'garuda', choice]), \
                     contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    status = iso_tools.main(['--dry-run'])
                self.assertEqual(status, 0, stderr.getvalue())
                self.assertIn(f'desktop = "{expected}"', stdout.getvalue())
                self.assertEqual(stderr.getvalue(), '')
                self.assertEqual(list((self.repo / 'iso-configs').iterdir()), [])

    def test_wizard_eof_cancels_without_writes(self):
        for answers in [[EOFError()], ['my_iso', EOFError()], ['my_iso', 'garuda', EOFError()]]:
            with self.subTest(answers=answers):
                stderr = io.StringIO()
                with patch.object(iso_tools, 'REPO', self.repo), \
                     patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), \
                     patch('builtins.input', side_effect=answers), \
                     contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(stderr):
                    status = iso_tools.main(['--dry-run'])
                self.assertEqual(status, 130)
                self.assertNotIn('Traceback', stderr.getvalue())
                self.assertEqual(list((self.repo / 'iso-configs').iterdir()), [])

    def test_explicit_bad_name_fails_before_any_wizard_prompt(self):
        stderr = io.StringIO()
        with patch.object(iso_tools.sys.stdin, 'isatty', return_value=True), \
             patch('builtins.input') as prompt, contextlib.redirect_stderr(stderr):
            status = iso_tools.main(['--name', '../escape', '--dry-run'])
        self.assertEqual(status, 1)
        prompt.assert_not_called()
        self.assertIn('reserved iso- prefix', stderr.getvalue())

    def test_cli_underscore_and_invalid_noninteractive_desktop(self):
        script = str(ROOT / 'scripts/build-iso.sh')
        for desktop, expected_status in [('hyprland', 0), ('garuda', 2)]:
            with self.subTest(desktop=desktop):
                result = subprocess.run(['bash', script, '--name', 'my_iso', '--username', 'garuda',
                                         '--desktop', desktop, '--dry-run'], text=True, capture_output=True)
                self.assertEqual(result.returncode, expected_status, result.stderr)
                self.assertNotIn('Traceback', result.stderr)
                if desktop == 'hyprland':
                    self.assertIn('PLAN: build iso-my_iso', result.stdout)
        self.assertFalse((ROOT / 'iso-configs/my_iso.nix').exists())

    def test_dry_run_and_symlink_protection(self):
        with contextlib.redirect_stdout(io.StringIO()):
            iso_tools.configure(self.repo, 'travel', 'alice', 'hyprland', dry_run=True)
        self.assertEqual(list((self.repo / 'iso-configs').iterdir()), [])
        (self.repo / 'iso-configs/travel.nix').symlink_to(self.base / 'personal')
        with self.assertRaises(SafetyError):
            iso_tools.configure(self.repo, 'travel', 'alice', 'hyprland')

    def test_output_must_be_external_and_not_devices(self):
        for bad in [self.repo, self.repo / 'out', '/dev/sda', '/boot/iso', '/nix/tmp', '/mnt/garuda/ISO', '/']:
            with self.subTest(path=bad), self.assertRaises(SafetyError):
                iso_tools.output_directory(self.repo, bad)
        self.assertEqual(iso_tools.output_directory(self.repo, self.base / 'out'), self.base / 'out')

    def test_successful_simulated_build_copies_real_iso_and_checksum(self):
        commands = []
        def fake_run(command, **kwargs):
            args = list(map(str, command)); commands.append(args)
            link = Path(args[args.index('--out-link') + 1])
            (link / 'iso').mkdir(parents=True)
            (link / 'iso/test.iso').write_bytes(b'ISO evaluation fixture, not a bootable image')
            return ''
        with patch.object(iso_tools, 'run', side_effect=fake_run), contextlib.redirect_stdout(io.StringIO()):
            path = iso_tools.build(self.repo, 'travel', self.base / 'out')
        self.assertTrue(path.is_file())
        self.assertIn(hashlib.sha256(path.read_bytes()).hexdigest(), path.with_suffix('.iso.sha256').read_text())
        self.assertIn('#nixosConfigurations.iso-travel.config.system.build.isoImage', commands[0][-1])
        self.assertEqual(commands[0][0], 'nix')
        self.assertFalse(any(c[0] in {'dd', 'mkfs', 'nixos-install'} for c in commands))

    def test_build_failure_and_output_collision_stop(self):
        with patch.object(iso_tools, 'run', side_effect=SafetyError('simulated build failure')), self.assertRaises(SafetyError):
            iso_tools.build(self.repo, 'travel', self.base / 'out')
        self.assertFalse(list((self.base / 'out').glob('*.iso')))
        source, dest = self.base / 'source.iso', self.base / 'personal.iso'
        source.write_bytes(b'new'); dest.write_bytes(b'personal')
        with self.assertRaises(FileExistsError): iso_tools.copy_iso(source, dest)
        self.assertEqual(dest.read_bytes(), b'personal')

    def test_dirty_unrelated_source_refused(self):
        with patch.object(iso_tools, 'run', side_effect=['README.md\0', '']), self.assertRaises(SafetyError):
            iso_tools.clean_for_build(self.repo, ['iso-configs/travel.nix'])
        with patch.object(iso_tools, 'run', side_effect=['iso-configs/travel.nix\0', '']):
            iso_tools.clean_for_build(self.repo, ['iso-configs/travel.nix'])

    def test_cli_dry_run_and_unknown_profile(self):
        script = str(ROOT / 'scripts/build-iso.sh')
        good = subprocess.run(['bash', script, '--name', 'travel-test', '--username', 'alice', '--dry-run'], text=True, capture_output=True)
        self.assertEqual(good.returncode, 0, good.stderr)
        self.assertIn('PLAN:', good.stdout)
        self.assertFalse((ROOT / 'iso-configs/travel-test.nix').exists())
        bad = subprocess.run(['bash', script, '--profile', '../escape', '--dry-run'], text=True, capture_output=True)
        self.assertEqual(bad.returncode, 1)

    def test_desktop_and_target_account_have_no_private_username_paths(self):
        for path in ['modules/applications/docker.nix', 'modules/system/virtualization.nix',
                     'home/ankur/home.nix', 'home/ankur/git.nix', 'home/ankur/hyprland/waybar/style.css']:
            text = (ROOT / path).read_text()
            self.assertNotIn('/home/ankur', text, path)
            self.assertNotIn('users.users.ankur', text, path)
            self.assertNotIn('comp2ankur@gmail.com', text, path)
        self.assertIn('name = "ankur"', (ROOT / 'hosts/nixos/identity.nix').read_text())
        live = (ROOT / 'modules/iso/live-installer.nix').read_text()
        self.assertIn('live-user-setup.service', live)
        self.assertIn('pkgs.shadow}/bin/passwd', live)
        self.assertIn('wheelNeedsPassword = lib.mkForce true', live)
        self.assertNotIn('initialPassword =', live)


if __name__ == '__main__': unittest.main()
