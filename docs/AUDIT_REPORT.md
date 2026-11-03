# Repository audit and verification report

Audit date: **3 November 2026**. Starting repository:
`https://github.com/AnkurAlpha/My-personal-nix-config`, default branch `main`,
base commit `c658ca8502dc45d58b82efcac7e1f775141ed4d6`.
The initial checkout was clean. No existing working tree on the user's computer
was modified; all work was performed in a separate clone.

## Implemented changes

- Added a beginner-oriented root README, indexed architecture/module reference,
  exact file inventory, module tutorial, command/recovery guide, desktop ownership
  guide, gaming/GPU matrix, maintenance guide and complete live installation guide.
- Reviewed all existing Markdown guides, retained specialist material, and corrected
  stale Btrfs/ext4, ZRAM, office defaults, Qt style, SDDM and absent-helper guidance.
  The earlier another-PC guide now points to the supported general workflow.
- Added `scripts/install.sh`, `scripts/new-host.sh` and their shared Python
  implementation. Default installation is a read-only plan; installed-system,
  path, mount, existing-data, source cleanliness, free-space and local-terminal
  guards fail closed. No formatting or repartitioning command is implemented.
- Added automatic new-host registration in `lib/hosts.nix`, isolated
  `modules/profiles/machine.nix` and a refreshed inactive host template.
  Original laptop/ISO/standalone Garuda outputs and input pins are retained.
- Added new-host graphics selection for Intel/AMD, hybrid NVIDIA and NVIDIA-only
  hardware. NVIDIA features are conditional; PRIME requires explicit bus IDs.
- Corrected HM Fish appearance/power-menu enable guards, the Waybar `nwgbar`
  executable typo, power-menu lock-item dependency and offload-wrapper guard.
  The original enabled host keeps its settings, keybinding commands and icons.
- Repaired ShellCheck errors and unsafe array handling in the existing read-only
  Waybar traffic helper, while retaining the `⇣`/`⇡` display. Default aggregation
  excludes loopback; counter deltas start from an initial sample.
- Added automated installer tests, documentation validation, optional Nix syntax
  validation and a Nix portability evaluation check for six GPU selections and
  two desktop profiles. Added `scripts/check.sh` as the local check entry point.

## Findings and ownership clarifications

| Finding | Resolution / retained behavior |
| --- | --- |
| No root README; module roles scattered | Added architecture, import/option examples, reference tables and index |
| Fixed-device reinstall scripts were the only installation path | Kept them for their original machine; added general tooling rather than adapting fixed disks for strangers |
| Hardware/user values spread through personal modules | New hosts use separate hardware and username/profile options; old Ankur-specific modules are documented rather than silently made global |
| ZRAM docs said disabled/50% | Actual host has 90% normal-priority capacity overriding a 50% default, Zstandard, swappiness 180; preserved |
| Kitty said not HM-managed | HM installs its package and raw config without `programs.kitty`; documented precedence of personal palette |
| Fish/power menu could outlive app switches | Guarded those HM definitions; system Fish login shell remains independent |
| Vivaldi, MPV/OBS, Signal have multiple providers | Preserved existing flags; documented every provider needed for complete removal |
| Plasma and SDDM have competing source definitions | Documented effective intended `mkForce` results; did not redesign working login/desktop |
| Generic maintenance flags do not disable direct host services | Documented active TRIM/root scrub and their actual scope |
| Garuda HM output is exported but mostly placeholder | Retained; activation/use history is unknown |
| Legacy `modules/development.nix` has no active import | Retained and identified as legacy |
| Empty `home/ankur/Building`, legacy raw Waybar asset | Retained; not active configuration |
| Direct services can overlap optional implementations | Documented PPD exclusivity, GameMode/Ananicy priority overlap and native option resolution |

No disk, partition, filesystem, EFI boot record, running service or personal
configuration was changed by executing the installer. No automatic cleanup,
model download, firmware update, NVIDIA overclock or unsafe power adjustment ran.
Original hardware UUIDs/bus IDs, Home Manager identity, Git identity, package pins,
kernel choice, ZRAM settings, Btrfs mounts and scrub selection were preserved.

## Executed checks

| Check | Result | Meaning |
| --- | --- | --- |
| Python safety/workflow suite | **28 tests passed** | Host injection/names, GPU arguments, idempotence, overwrite/symlink guards, exact mounts, disk validation, existing data, shared ESP, space, confirmation, failures/interruption, simulated build/install ordering and CLI preview |
| Read-only network helper runtime | **Passed** within suite | Real loopback counters produced valid bounded-percentage JSON; no network/device settings changed |
| Bash syntax | **Passed** | All tracked shell scripts and executable calendar helper parsed |
| ShellCheck 0.11.0 | **Passed** | All tracked shell scripts checked; original traffic-helper errors corrected |
| Nix Tree-sitter syntax | **Passed: 114 files/templates + 12 generated variants** | Syntax only; not module option resolution, Nix evaluation or compilation |
| Markdown local links/fences/index | **Passed** | Every local linked path exists, fenced blocks close, root guides indexed |
| Git whitespace/conflict-marker review | **Passed** | Reviewed staged diff and checked whitespace; no merge conflicts |
| Credential pattern scan | **Passed** | No detected private-key blocks or common GitHub/AWS credential patterns in tracked text; not a formal secret-scanning guarantee |
| `flake.lock` identity | **Unchanged** | No package/input update was performed |

Optional parser tooling used Tree-sitter 0.26.0 and tree-sitter-nix 0.1.0.
`requirements-audit.txt` records reproducible auxiliary-tool versions for
non-Nix environments. NixOS users should use native `nix-instantiate --parse` and
flake evaluation in addition to syntax parsing.

## Checks unavailable here

The workspace is Ubuntu, with approximately **2.6 GB free disk** at initial
inspection, and no `nix`, `nix-instantiate`, QEMU or NixOS live installation tools.
Attempts to obtain Nix through system packages and the official binary distribution
did not yield a usable installation (package-cache permissions and network timeouts).
A small standalone ShellCheck and Nix parser were available via Python packages.
During final QA, shared workspace storage briefly filled and caused temporary-file
errors. After moving this task's temporary check tools to memory-backed storage,
the complete final suite passed again; the final disk-space check showed about
19 GB available. Native Nix remained unavailable independently of that recovery.

Consequently, these were **not executed** and are **not claimed as passed**:

- Native Nix evaluation, `nix flake check`, and the new portability evaluation check.
- Building the existing laptop's system closure or the installer ISO.
- VM installation to a disposable disk image, UEFI/legacy boot, or physical installation.
- Real NVIDIA/non-NVIDIA runtime driver checks, GameMode policy tests, display
  behavior, suspend/resume, thermals, power profiles or performance benchmarks.

The Python suite simulates command orchestration, including proving a failed build
cannot reach `nixos-install`; it is not a substitute for a real installation.
Configuration syntax and conditional-source review do not prove that every option
exists in the locked inputs. Treat new profiles/tooling as reviewable, implemented
code awaiting the following native Nix/boot validation, not hardware-certified work.

## Required native validation before using installation on hardware

```bash
bash scripts/check.sh
nix flake check --no-update-lock-file
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
# Optional independent live ISO build, with sufficient disk space:
nix build --no-link .#nixosConfigurations.ankur-installer-iso.config.system.build.isoImage
```

The flake check includes the 12 new-profile GPU/desktop **evaluation** fixtures;
it checks assertions, NVIDIA conditional flags and toplevel derivations without
installing those dummy-disk fixtures. It does not build every fixture system closure.
Generate a host on an actual target, stage it, evaluate/build it, then test a
prepared-mode install in a disposable VM before relying on it on personal hardware.
Test fresh Btrfs preparation separately on an intentionally empty disposable
filesystem. Never run formatting or installation as an audit check on user data.

For the original laptop, verify its build, use `nh os test` on the real laptop and
confirm Waybar icons/profile cycling, Fish prompt, menu actions, SDDM login, PRIME,
GameMode, Ananicy and timers. Reboot for kernel/GPU/ZRAM changes only if deliberately
made later. For another PC check firmware boot selection, ESP capacity/type,
root/subvolume mounts, credentials, GPU device selection, sound/network and
suspend/resume. Keep a rescue USB and backups until all operating systems boot.

## Publication

Changes are committed on the dedicated `codex/nixos-docs-installer-2026-11-03`
review branch. The GitHub dry-run push failed because HTTPS authentication was
unavailable (`could not read Username`, terminal prompts disabled). No remote
branch or PR was created. The delivery includes the committed source, a patch
and a Git bundle so the work can be reviewed/applied without losing the commit.
See its apply instructions for exact hashes. No force-push,
main-branch overwrite or repository permission change is part of this task.
