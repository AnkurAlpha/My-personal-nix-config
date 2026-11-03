# Commands, Git workflow and recovery

Examples assume Bash in `~/nixos-config`, original host `nixos`. For another host,
replace the flake attribute and path deliberately. This repo enables flakes and
nix-command in NixOS; live USBs may need
`nix --extra-experimental-features 'nix-command flakes' ...`.

## Build and activate

| Command | Effect / when to use |
| --- | --- |
| `nh os build . -H nixos` | Build and display changes without activation |
| `nh os test . -H nixos` | Build and activate now; does not make it the next-boot default |
| `nh os switch . -H nixos` | Build, activate now, select new boot generation |
| `nh os boot . -H nixos` | Build and select next boot; leave current runtime alone |
| `sudo nixos-rebuild build --flake .#nixos` | Native build alternative; inspect the result link |
| `sudo nixos-rebuild test --flake .#nixos` | Native temporary activation |
| `sudo nixos-rebuild switch --flake .#nixos` | Native persistent activation |
| `sudo nixos-rebuild boot --flake .#nixos` | Native next-boot activation |
| `nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel` | Build system closure only; no result GC root is retained by this command |
| `nix flake check --no-build --no-update-lock-file` | Evaluate output types/check derivations; do not build checks or alter pins |
| `nix flake check --no-update-lock-file` | Also build declared checks; does not build the entire NixOS host closure merely because it is an output |
| `bash scripts/check.sh` | Safety tests, syntax and available flake evaluation; no activation |
| `bash scripts/check.sh --static` | Local checks without flake input fetching |

`nh` handles privilege elevation; normally invoke it as your regular user.
Check installed `nh os --help` when versions differ. `test` is a real activation,
so do it from a recoverable local session if changing networking or login.
Do not combine `nixos-rebuild` and a standalone HM switch for this integrated home.

Reboot for a new running kernel, changed kernel-driver stack, bootloader/initrd
behavior or root mounting policy. NVIDIA kernel/userspace versions should match;
reboot after driver changes. A ZRAM resize or udev scheduler change may also be
best verified after reboot. Ordinary user config changes need an app restart or
new login; service configuration usually restarts its service during activation.
Inspect the affected unit before manually restarting it. `systemctl daemon-reload`
alone does not apply a changed service's running behavior.

## Evaluate, inspect and debug

```bash
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --raw .#nixosConfigurations.nixos.config.networking.hostName
nix eval --json .#nixosConfigurations.nixos.config.zramSwap
nix eval --json .#nixosConfigurations.nixos.config.hardware.nvidia.prime.offload.enable
nix eval --json .#nixosConfigurations.nixos.config.hardware.nvidia.prime.sync.enable
nix eval --raw .#nixosConfigurations.nixos.config.services.displayManager.sddm.theme
nix eval --json .#nixosConfigurations.nixos.options.services.power-profiles-daemon.enable.declarations
nix eval --json .#nixosConfigurations.nixos.options.zramSwap.memoryPercent.definitionsWithLocations --apply 'xs: map (x: { inherit (x) file value; }) xs'
nix eval --show-trace --raw .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
nix eval --json .#nixosConfigurations.nixos.config.assertions --apply 'xs: map (x: x.message) (builtins.filter (x: !x.assertion) xs)'
```

The last command should print `[]`. Evaluating one option does not prove every
option/package builds. Inspect both `environment.systemPackages` and HM
`home.packages` when locating package ownership; transitive dependencies and
imperative profiles add another layer.

```bash
rg -n 'power-profiles|tlp|auto-cpufreq|tuned|cpuFreqGovernor' hosts modules
nix-instantiate --parse modules/system/power-battery.nix >/dev/null
nix flake metadata --no-update-lock-file
```

Common failures: untracked new files are missing from a Git flake; two modules set
conflicting scalars; a module was removed while another references its options;
a package/option differs in the pinned release; a new driver needs reboot. Read
the first concrete error and its definition locations before adding `mkForce`.

## Inputs, packages and development

| Command | Meaning |
| --- | --- |
| `nix flake update home-manager` | Update that moving input's lock and needed dependencies; review diff/build |
| `nix flake update` | Re-resolve all inputs; explicit revision pins remain fixed; not an activation |
| `nix-update-safe status` | Existing read-only pin/Git report |
| `nix-update-safe safe-all` | Existing guarded manual updater: build, confirm, switch, optional commit |
| `nix search nixpkgs '^ripgrep$'` | Search the registry's Nixpkgs, which may differ from the repo pin |
| `nix shell nixpkgs#jq --command jq --version` | One temporary command |
| `nix develop .#cpp` | Enter this repo's locked C++ shell |
| `nix develop .#python --command python --version` | Run one command in its Python shell |
| `nix-dev list` | List enabled shells through the existing wrapper |

The updater is host-specific and requires a clean Git checkout. It protects
FIMLoom, SmoothCursor and the explicit Nixpkgs pin. Its failed pre-activation paths
restore flake files; a failed switch may still have partially changed services.
It does not automatically reboot, schedule updates or push.

## Store, generations and comparisons

```bash
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
nix store info
nix path-info -Sh /run/current-system
nix store diff-closures /run/booted-system /run/current-system
nix-store --query --requisites /run/current-system
nix-store --gc --print-roots
nix profile list
```

`nix store` groups inspection, repair/copy and garbage-collection operations.
Use inspection subcommands first. `nix store diff-closures` compares package
closures, not mutable home data or every configuration file. `nvd diff` can also
compare two retained generation paths. A build `result` link is a GC root;
`--no-link` builds without retaining that additional root. Do not manually alter
or remove `/nix/store` files. `nix store verify` can verify content but is a
potentially expensive diagnostic, not needed after every small change.

Generation directories and boot entries refer to system closures. A failed boot
can often be recovered by selecting an older retained boot generation. Deleting
its profile/root and collecting its closure removes that recovery path. A Btrfs
snapshot is different: it may capture mutable data, depending on selected
subvolumes. Neither mechanism replaces an off-device backup.

## Rollback

From a working local terminal:

```bash
sudo nixos-rebuild switch --rollback
systemctl --failed
git log --oneline -8
# After identifying the exact bad source commit:
git revert BAD_COMMIT
```

Replace `BAD_COMMIT` with the reviewed hash. `git revert` records an inverse change;
it does not discard unrelated uncommitted work. A configuration rollback does not
undo app/database migrations or restore deleted personal files. If graphical
login fails, switch to a TTY, inspect the display-manager journal and select a
known-good generation. If no system boots, use the live USB, mount the **actual**
root/subvolumes/ESP and repair from the correct flake; do not reinstall/format
other partitions as a shortcut.

## Cleanup: review recovery consequences first

`nh clean` and `nix-collect-garbage` are explicit maintenance commands. They can
remove generations, GC roots and store objects needed for rollback or cached
shells. `nh clean` can also remove result/Direnv roots depending on version/options.
Keep known-good generations and off-device backups. Do not schedule cleanup just
to make the configuration look tidy.

```bash
nh clean all --help
nh clean all --dry --keep 5 --keep-since 14d
```

Confirm the installed version supports these flags before using them; the dry run
is the review step. `--keep` refers to generations, not disk/ISO images. Retention
may preserve additional generations because of age/current-profile protections.
Only after checking the dry run and understanding which roots disappear, remove
`--dry` to perform the chosen cleanup. No cleanup command is run by the installer.

`sudo nix-collect-garbage --delete-older-than 30d` deletes old generations and then
collects unreachable store paths; it reduces recovery options. `-d` deletes **all
old generations**, so do not use it as a routine recommendation. Plain
`sudo nix-collect-garbage` collects unreachable objects without requesting that
all generations be deleted. System and per-user profiles have distinct roots.
After intentionally deleting system generations, review/rebuild boot entries;
do not delete boot files by hand or run boot-entry removal as an installation step.

## Services and logs

```bash
systemctl --failed
systemctl status power-profiles-daemon irqbalance ananicy --no-pager
systemctl cat ananicy
journalctl -b -u ananicy --no-pager
systemctl --user status gamemoded hyprsunset
journalctl --user -b -u gamemoded --no-pager
systemctl list-timers --all
systemctl --user list-timers --all
```

System units and user units are separate; use `--user` for the latter. Ananicy C++
may run under a unit named `ananicy` despite the package's name; inspect
`systemctl list-unit-files '*ananicy*'`. `enable` controls startup wiring, `start`
starts now, and `restart` interrupts the existing process. Make persistent unit
changes declaratively; imperative `systemctl enable` is not the source of truth
for a NixOS-managed unit.

## Git workflow

```bash
git status --short --branch
git pull --ff-only
git switch -c feature/my-change
# Edit source; add new paths before evaluating the Git flake.
git add PATHS_YOU_REVIEWED
git diff --cached --check
git diff --cached
bash scripts/check.sh
nh os build . -H nixos
# If appropriate, test/switch and inspect runtime behavior.
git commit -m "Describe the concrete change"
git push -u origin feature/my-change
```

Replace `PATHS_YOU_REVIEWED` with actual reviewed paths; do not publish passwords,
shadow files, private keys, license material or tokens. A configured Git identity
is not authentication. SSH authentication does not authorize an HTTPS remote
unless a corresponding credential method is configured. `git pull --ff-only`
stops on divergence instead of creating an unexpected merge; resolve it explicitly.
Commit after successful validation; do not commit with `--no-verify` to hide a
failed check. Push a review branch when changing an existing working system.
