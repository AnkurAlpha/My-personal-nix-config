"""Exercise the real update CLI with a linked worktree and simulated builds."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

UPDATER = Path(__file__).resolve().parents[1] / "modules/system/nix-update-safe.sh"


@unittest.skipUnless(os.geteuid() and shutil.which("jq") and shutil.which("flock"),
                     "The updater needs a regular user, jq and flock")
class UpdateTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        self.repo = base / "main"
        self.candidate = base / "update"
        self.log = base / "commands"
        self.repo.mkdir()
        self.git("init", "-q")
        (self.repo / "flake.nix").write_text("{}\n")
        names = ("nixpkgs", "home-manager", "nixvim", "nvimEmmet",
                 "vimReactSnippets", "fimloom", "smoothcursor", "neominimap")
        lock = {"root": "root", "nodes": {"root": {"inputs": dict(zip(names, names))}}}
        (self.repo / "flake.lock").write_text(json.dumps(lock) + "\n")
        (self.repo / "scripts").mkdir()
        (self.repo / "scripts/check.sh").write_text('echo "check" >> "$UPDATE_TEST_LOG"\n')
        (self.repo / "scripts/build-iso.sh").write_text('echo "iso $*" >> "$UPDATE_TEST_LOG"\n')
        (self.repo / "iso-configs").mkdir()
        for profile in ("my_nix_garuda_iso", "my_iso"):
            (self.repo / "iso-configs" / f"{profile}.nix").touch()
        self.git("add", ".")
        self.git("-c", "user.name=Update Tests", "-c", "user.email=tests@example.invalid",
                 "commit", "-qm", "baseline")
        self.git("worktree", "add", "--detach", "-q", str(self.candidate))

        binaries = base / "bin"
        binaries.mkdir()
        stubs = {
            "nix": '''
echo "nix $*" >> "$UPDATE_TEST_LOG"
if [[ "$1 $2" == "flake update" ]]; then printf '\\n' >> flake.lock; fi
''',
            "nh": '''
echo "nh $*" >> "$UPDATE_TEST_LOG"
[[ "$1 $2" == "os build" ]] || exit 98
exit "${UPDATE_TEST_BUILD_STATUS:-0}"
''',
        }
        for name, body in stubs.items():
            script = binaries / name
            script.write_text("#!/usr/bin/env bash\n" + body)
            script.chmod(0o755)
        self.env = {
            **os.environ, "PATH": f"{binaries}:{os.environ['PATH']}",
            "UPDATE_TEST_LOG": str(self.log), "NIX_UPDATE_REPO": str(self.repo),
            "NIX_UPDATE_HOST": "nixos", "NIX_UPDATE_FIMLOOM": "false",
        }

    def git(self, *args, repo=None):
        return subprocess.run(["git", "-C", str(repo or self.repo), *args],
                              check=True, text=True, capture_output=True).stdout

    def update(self, *args):
        return subprocess.run(["bash", str(UPDATER), *args], cwd=self.candidate,
                              env=self.env, text=True, capture_output=True)

    def test_system_update_builds_only_in_candidate_worktree(self):
        (self.repo / "flake.nix").write_text("{ staged = true; }\n")
        self.git("add", "flake.nix")
        staged = self.git("diff", "--cached")
        original_head = self.git("rev-parse", "HEAD")
        result = self.update("prepare", "system", "my_iso")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("diff --git a/flake.lock", result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), [
            "nix flake update nixpkgs home-manager nixvim",
            "check",
            "nix flake check --no-update-lock-file",
            "nh os build . -H nixos --no-update-lock-file",
            'nix build --no-link --no-update-lock-file .#homeConfigurations."ankur@garuda".activationPackage',
            "iso --profile my_iso --validate-only",
        ])
        self.assertEqual(self.git("status", "--porcelain", repo=self.candidate), " M flake.lock\n")
        self.assertEqual(self.git("rev-parse", "HEAD", repo=self.candidate), original_head)
        self.assertEqual(self.git("diff", "--cached"), staged)

    def test_editor_group_and_fixed_sources(self):
        for name in ("smoothcursor", "neominimap", "missing"):
            with self.subTest(name=name):
                self.assertNotEqual(self.update("prepare", "input", name).returncode, 0)
        self.assertFalse(self.log.exists())
        result = self.update("prepare", "editor")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "nix flake update nvimEmmet vimReactSnippets",
            "check",
            "nix flake check --no-update-lock-file",
            "nh os build . -H nixos --no-update-lock-file",
        ])

    def test_fimloom_requires_an_explicit_request(self):
        guarded = self.update("prepare", "input", "fimloom")
        self.assertNotEqual(guarded.returncode, 0)
        self.assertIn("--allow-fimloom", guarded.stderr)
        self.assertFalse(self.log.exists())
        result = self.update("prepare", "input", "fimloom", "--allow-fimloom")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("nix flake update fimloom\n", self.log.read_text())

    def test_failed_build_leaves_candidate_for_validation_retry(self):
        self.env["UPDATE_TEST_BUILD_STATUS"] = "19"
        failed = self.update("prepare", "input", "nvimEmmet")
        self.assertEqual(failed.returncode, 19, failed.stderr)
        candidate_lock = (self.candidate / "flake.lock").read_bytes()
        self.assertNotEqual(candidate_lock, (self.repo / "flake.lock").read_bytes())
        del self.env["UPDATE_TEST_BUILD_STATUS"]
        self.log.unlink()
        retry = self.update("validate")
        self.assertEqual(retry.returncode, 0, retry.stderr)
        self.assertNotIn("flake update", self.log.read_text())
        self.assertEqual((self.candidate / "flake.lock").read_bytes(), candidate_lock)

    def test_parallel_update_in_same_worktree_is_refused(self):
        git_dir = Path(self.git("rev-parse", "--absolute-git-dir", repo=self.candidate).strip())
        with (git_dir / "nix-update-safe.lock").open("w") as lock_file:
            fcntl.flock(lock_file, fcntl.LOCK_EX)
            result = self.update("prepare", "editor")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already running in this worktree", result.stderr)
        self.assertFalse(self.log.exists())
