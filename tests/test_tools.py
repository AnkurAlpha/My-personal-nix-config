"""Hardware-independent safety tests. No real mounts or installation commands run."""
import contextlib
import dataclasses
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("nixos_tools", ROOT / "scripts/nixos_tools.py")
tools = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = tools
spec.loader.exec_module(tools)
HARDWARE = '{ ... }: { fileSystems."/" = { device = "/dev/disk/by-uuid/test"; fsType = "btrfs"; }; nixpkgs.hostPlatform = "x86_64-linux"; }\n'


class HostTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / "hosts").mkdir()
        (self.repo / "lib").mkdir()
        (self.repo / "lib/hosts.nix").touch()
        (self.repo / "flake.nix").touch()

    def test_all_supported_graphics(self):
        for gpu in tools.GRAPHICS:
            with self.subTest(gpu=gpu):
                hybrid = "-nvidia" in gpu
                host = tools.Host("test-" + gpu, "alice", graphics=gpu,
                                  integrated_bus_id="PCI:5@0:0:0" if hybrid else "",
                                  nvidia_bus_id="PCI:1@0:0:0" if hybrid else "")
                dest = tools.create_host(self.repo, host, HARDWARE, "btrfs")
                self.assertIn(f'graphics = "{gpu}"', (dest / "configuration.nix").read_text())
                self.assertNotIn("hosts/nixos", (dest / "configuration.nix").read_text())

    def test_injection_and_reserved_names(self):
        for bad in ["../escape", 'a";throw', "a${builtins.abort}", "-foo", "Foo", "a_b", "pc-", "nixos", "installer-iso", "a" * 64]:
            with self.subTest(name=bad), self.assertRaises(tools.SafetyError):
                tools.Host(bad, "alice").validate()
        for bad in ["root", "nobody", "a;id", "../alice", "a\nwhoami"]:
            with self.subTest(user=bad), self.assertRaises(tools.SafetyError):
                tools.Host("newpc", bad).validate()

    def test_missing_or_same_prime_ids(self):
        for igpu, dgpu in [("", ""), ("PCI:1:0:0", "PCI:1:0:0"), ("0a:00.0", "PCI:1:0:0")]:
            with self.assertRaises(tools.SafetyError):
                tools.Host("newpc", "alice", graphics="amd-nvidia", integrated_bus_id=igpu, nvidia_bus_id=dgpu).validate()

    def test_idempotent_and_never_overwrites_custom_changes(self):
        host = tools.Host("newpc", "alice")
        dest = tools.create_host(self.repo, host, HARDWARE, "btrfs")
        original = (dest / "configuration.nix").read_bytes()
        self.assertEqual(dest, tools.create_host(self.repo, host, HARDWARE, "btrfs"))
        (dest / "configuration.nix").write_text("personal changes")
        with self.assertRaises(tools.SafetyError):
            tools.create_host(self.repo, host, HARDWARE, "btrfs")
        self.assertEqual((dest / "configuration.nix").read_text(), "personal changes")
        self.assertTrue(original)

    def test_symlinks_refused(self):
        (self.repo / "hosts/newpc").symlink_to(self.repo)
        with self.assertRaises(tools.SafetyError):
            tools.create_host(self.repo, tools.Host("newpc", "alice"), HARDWARE, "btrfs")

    def test_dry_run_writes_nothing(self):
        with contextlib.redirect_stdout(io.StringIO()):
            tools.create_host(self.repo, tools.Host("newpc", "alice"), HARDWARE, "btrfs", dry_run=True)
        self.assertEqual(list((self.repo / "hosts").iterdir()), [])

    def test_ext4_no_scrub_legacy_no_efi(self):
        content = tools.render_host(tools.Host("oldpc", "alice", boot="legacy", disk="/dev/sdz"), "ext4")
        self.assertIn('grub.device = "/dev/sdz"', content)
        self.assertNotIn("autoScrub", content)
        self.assertNotIn("systemd-boot", content)

    def test_string_interpolation_is_escaped(self):
        self.assertIn(r"\${", tools.nix_string("${throw}"))

    def test_unsupported_inputs_stop(self):
        for changes in [dict(graphics="nouveau"), dict(system="aarch64-linux"), dict(timezone='UTC";throw'),
                        dict(boot="legacy"), dict(disk="/dev/sda"), dict(gaming=True)]:
            with self.subTest(changes=changes), self.assertRaises(tools.SafetyError):
                dataclasses.replace(tools.Host("newpc", "alice"), **changes).validate()


class InstallerTests(unittest.TestCase):
    def test_target_paths(self):
        for root in ["/", "/home", "/mnt/../etc", "mnt", "/etc", "/mntgaruda"]:
            with self.subTest(root=root), self.assertRaises(tools.SafetyError):
                tools.validate_target_root(root)
        self.assertEqual(tools.validate_target_root("/mnt"), Path("/mnt"))

    def test_mount_must_be_exact(self):
        with self.assertRaises(tools.SafetyError):
            tools.exact_mount([dict(target="/", source="overlay")], "/mnt")

    def test_fake_disk_refused(self):
        with patch.object(tools, "block_device", return_value=True):
            for disk in ["/dev/sdz1", "/dev/nonexistent", "x;whoami"]:
                with self.subTest(disk=disk), self.assertRaises(tools.SafetyError):
                    tools.validate_disk(disk, [dict(path="/dev/sdz", type="disk", children=[])])

    def test_legacy_wrong_disk_and_missing_bios_partition(self):
        inventory = [dict(path="/dev/sdz", type="disk", children=[dict(path="/dev/sdz1", type="part", parttype="linux-guid")])]
        with patch.object(tools, "block_device", return_value=True):
            for source in ["/dev/sdx1", "/dev/sdz1"]:
                with self.assertRaises(tools.SafetyError):
                    tools.validate_disk("/dev/sdz", inventory, source)

    def test_no_confirmation_from_pipe(self):
        with patch("sys.stdin", io.StringIO("INSTALL x AT /mnt\n")), self.assertRaises(tools.SafetyError):
            tools.confirm("INSTALL x AT /mnt")

    def test_cancelled_confirmation_stops(self):
        with contextlib.redirect_stdout(io.StringIO()), patch("sys.stdin.isatty", return_value=True), \
             patch("sys.stdout.isatty", return_value=True), patch("builtins.input", return_value="no"), self.assertRaises(tools.SafetyError):
            tools.confirm("INSTALL x AT /mnt")

    def test_prepared_overlay_and_readonly_stop(self):
        for fs, options in [("overlay", "rw"), ("btrfs", "ro")]:
            records = [dict(target="/mnt", source="/dev/sdz1", fstype=fs, options=options)]
            with self.assertRaises(tools.SafetyError):
                tools.validate_prepared("/mnt", "uefi", records)

    def test_running_root_device_rejected(self):
        records = [dict(target="/mnt", source="/dev/sdz1[/@root]", fstype="btrfs", options="rw"),
                   dict(target="/", source="/dev/sdz1[/@other]", fstype="btrfs", options="rw")]
        with patch.object(tools, "block_device", return_value=True), self.assertRaises(tools.SafetyError):
            tools.validate_prepared("/mnt", "uefi", records)

    def test_plan_never_runs_mutating_commands(self):
        args = tools.argparse.Namespace(host="newpc", username="alice", graphics="amd", desktop="minimal",
            boot="uefi", disk=None, integrated_bus_id=None, nvidia_bus_id=None, closed_nvidia=False,
            gaming=False, bluetooth=False, power_profiles=False, timezone="UTC", root="/mnt",
            mode="fresh", root_device="/dev/sdz2", boot_device="/dev/sdz1", allow_shared_esp=False,
            install=False, resume=False)
        with tempfile.TemporaryDirectory() as empty_target, \
             patch.object(tools, "validate_target_root", return_value=Path(empty_target)), \
             patch.object(tools, "need_tools"), patch.object(tools, "mounts", return_value=[]), \
             patch.object(tools, "block_inventory", return_value=[
                 dict(path="/dev/sdz1", type="part", fstype="vfat"),
                 dict(path="/dev/sdz2", type="part", fstype="btrfs")]), \
             patch.object(tools, "block_device", return_value=True), patch.object(tools, "run") as execute, \
             contextlib.redirect_stdout(io.StringIO()) as out:
            tools.install(args)
            execute.assert_not_called()
            self.assertIn("PLAN ONLY", out.getvalue())

    def test_command_failure_and_interrupt_stop(self):
        with patch("subprocess.run", side_effect=subprocess.CalledProcessError(1, ["nix"])), self.assertRaises(tools.SafetyError):
            tools.run(["nix", "build"])
        with patch("subprocess.run", side_effect=KeyboardInterrupt), self.assertRaises(KeyboardInterrupt):
            tools.run(["nix", "build"])

    def test_probe_unmounts_on_failure(self):
        with patch.object(tools, "need_tools"), patch.object(tools, "run", return_value="") as execute:
            with self.assertRaises(tools.SafetyError):
                with tools.probe_empty_btrfs("/dev/sdz2"):
                    raise tools.SafetyError("cancelled")
            self.assertEqual(execute.call_args.args[0][0], "umount")


class PreparedFilesystemTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "boot").mkdir()
        self.records = [dict(target=str(self.root), source="/dev/sdz2[/@root]", fstype="btrfs", options="rw,subvol=/@root"),
                        dict(target=str(self.root / "boot"), source="/dev/sdz1", fstype="vfat", options="rw")]
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(tools, "validate_target_root", return_value=self.root))
        self.stack.enter_context(patch.object(tools, "block_device", return_value=True))
        self.stack.enter_context(patch.object(tools.shutil, "disk_usage", return_value=tools.shutil._ntuple_diskusage(64*1024**3, 1, 32*1024**3)))

    def test_empty_prepared_target_accepted(self):
        self.assertEqual(tools.validate_prepared(self.root, "uefi", self.records)["fstype"], "btrfs")

    def test_existing_os_and_home_and_etc_refused(self):
        for relative in ["etc/os-release", "home/alice/precious.txt", "etc/ssh/config", "Windows/data"]:
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("personal")
                with self.assertRaises(tools.SafetyError):
                    tools.validate_prepared(self.root, "uefi", self.records)
                path.unlink()
                while path.parent != self.root:
                    parent = path.parent
                    parent.rmdir()
                    path = parent

    def test_shared_esp_needs_explicit_opt_in(self):
        (self.root / "boot/EFI").mkdir()
        (self.root / "boot/EFI/other.efi").touch()
        with self.assertRaises(tools.SafetyError):
            tools.validate_prepared(self.root, "uefi", self.records)
        with contextlib.redirect_stdout(io.StringIO()):
            tools.validate_prepared(self.root, "uefi", self.records, allow_shared=True)
        self.assertTrue((self.root / "boot/EFI/other.efi").exists())

    def test_live_submount_and_symlink_refused(self):
        (self.root / "nix").symlink_to("/nix")
        with self.assertRaises(tools.SafetyError):
            tools.validate_prepared(self.root, "uefi", self.records)
        (self.root / "nix").unlink()
        records = self.records + [dict(target="/nix", source="/dev/sdx3", fstype="ext4", options="rw"),
                                   dict(target=str(self.root / "nix"), source="/dev/sdx3", fstype="ext4", options="rw")]
        with self.assertRaises(tools.SafetyError):
            tools.validate_prepared(self.root, "uefi", records)

    def test_insufficient_space_refused(self):
        with patch.object(tools.shutil, "disk_usage", return_value=tools.shutil._ntuple_diskusage(100, 99, 1)), self.assertRaises(tools.SafetyError):
            tools.validate_prepared(self.root, "uefi", self.records)


class WorkflowTests(unittest.TestCase):
    def test_failed_build_cannot_reach_install_and_success_order(self):
        for fail_build in [True, False]:
            with self.subTest(fail_build=fail_build), tempfile.TemporaryDirectory() as temp:
                base = Path(temp)
                source, root = base / "source", base / "mnt"
                source.mkdir(); root.mkdir()
                (source / "lib").mkdir(); (source / "hosts").mkdir(); (source / ".git/info").mkdir(parents=True)
                (source / "lib/hosts.nix").touch(); (source / "flake.nix").touch()
                calls = []
                def fake_run(command, **kwargs):
                    command = [str(c) for c in command]
                    calls.append(command)
                    if command[:2] == ["git", "clone"]:
                        tools.shutil.copytree(source, command[-1])
                    if command[:3] == ["git", "remote", "get-url"]:
                        return "https://github.com/example/config.git"
                    if command[:2] == ["git", "rev-parse"]:
                        return "test-revision"
                    if command[0] == "nixos-generate-config":
                        return HARDWARE
                    if command[0] == "nix" and "--raw" in command:
                        return "newpc"
                    if command[0] == "nix" and "--json" in command:
                        return "[]"
                    if command[0] == "nix" and "build" in command and fail_build:
                        raise tools.SafetyError("simulated build failure")
                    return ""
                args = tools.argparse.Namespace(host="newpc", username="alice", graphics="amd", desktop="minimal",
                    boot="uefi", disk=None, integrated_bus_id=None, nvidia_bus_id=None, closed_nvidia=False,
                    gaming=False, bluetooth=False, power_profiles=False, timezone="UTC", root=str(root),
                    mode="prepared", root_device=None, boot_device=None, allow_shared_esp=False,
                    install=True, resume=False)
                with contextlib.ExitStack() as stack:
                    stack.enter_context(patch.object(tools, "REPO", source))
                    stack.enter_context(patch.object(tools, "need_tools"))
                    stack.enter_context(patch.object(tools, "check_live"))
                    stack.enter_context(patch.object(tools, "confirm"))
                    stack.enter_context(patch.object(tools, "validate_target_root", return_value=root))
                    stack.enter_context(patch.object(tools, "mounts", return_value=[]))
                    stack.enter_context(patch.object(tools, "block_inventory", return_value=[]))
                    stack.enter_context(patch.object(tools, "validate_prepared", return_value=dict(source="/dev/sdz2", fstype="btrfs")))
                    stack.enter_context(patch("sys.stdin.isatty", return_value=True))
                    stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
                    stack.enter_context(patch("sys.stdout.isatty", return_value=True))
                    stack.enter_context(patch.object(tools, "run", side_effect=fake_run))
                    if fail_build:
                        with self.assertRaises(tools.SafetyError): tools.install(args)
                    else:
                        tools.install(args)
                self.assertTrue(any(c[0] == "nix" and "build" in c for c in calls))
                installs = [i for i, c in enumerate(calls) if c[0] == "nixos-install"]
                self.assertEqual(len(installs), 0 if fail_build else 1)
                if not fail_build:
                    builds = [i for i, c in enumerate(calls) if c[0] == "nix" and "build" in c]
                    self.assertLess(builds[0], installs[0])
                    self.assertEqual(calls[-1][-1], "passwd alice")
                self.assertFalse((source / "hosts/newpc").exists())

    def test_cli_invalid_host_and_readonly_new_host(self):
        with tempfile.TemporaryDirectory() as temp:
            hardware = Path(temp) / "hardware.nix"; hardware.write_text(HARDWARE)
            common = ["bash", str(ROOT / "scripts/new-host.sh"), "--hardware", str(hardware), "--root-fs", "btrfs", "--username", "alice"]
            bad = subprocess.run(common + ["--host", "../escape", "--dry-run"], capture_output=True, text=True)
            self.assertEqual(bad.returncode, 1)
            good = subprocess.run(common + ["--host", "cli-preview-only", "--dry-run"], capture_output=True, text=True)
            self.assertEqual(good.returncode, 0, good.stderr)
            self.assertFalse((ROOT / "hosts/cli-preview-only").exists())

    def test_network_helper_real_readonly_output_and_bad_inputs(self):
        script = str(ROOT / "home/ankur/hyprland/waybar/scripts/network_traffic.sh")
        bad = subprocess.run(["bash", script, "-t", "0"], capture_output=True, text=True)
        self.assertEqual(bad.returncode, 2)
        self.assertEqual(json.loads(bad.stdout)["class"], "error")
        if Path("/sys/class/net/lo/statistics/rx_bytes").exists():
            result = subprocess.run(["timeout", "2.2", "bash", script, "-t", "1", "lo"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 124)
            messages = [json.loads(line) for line in result.stdout.splitlines()]
            self.assertGreaterEqual(len(messages), 1)
            self.assertTrue(all(0 <= m["percentage"] <= 100 for m in messages))


if __name__ == "__main__":
    unittest.main()
