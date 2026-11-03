# Gaming, GameMode and graphics

## Configuration ownership

On the original laptop, `hosts/nixos/gaming.nix` declares/selects
`my.apps.gaming` and enables **NixOS** Steam and GameMode integration.
`home/ankur/applications/gaming.nix` installs the optional MangoHud overlay and an
offload wrapper. GPU drivers and PRIME settings come from `hosts/nixos/gpu.nix`
and `modules/hardware/nvidia-hybrid.nix`. None of these roles is interchangeable.

Garuda goodies also supplies a `mkDefault true` GameMode enable. To disable
GameMode, reconcile both providers; changing only one high-level flag may still
leave the native service enabled. Evaluate `programs.gamemode.enable` after editing.

## What GameMode does

GameMode is a client/daemon system that applies supported, configured policies
while requesting games run and releases them afterward. `gamemoderun` makes an
application request that mode. Depending on configuration and available kernel
interfaces, policies can concern CPU governors, I/O scheduling priority, process
nice values and other settings. It does not choose the rendering GPU, install a
game, fix compatibility problems or guarantee higher FPS.

This repository enables GameMode but deliberately disables its renice feature:
`programs.gamemode.enableRenice = false` and `settings.general.renice = 0` are
Garuda-goodies defaults. Ananicy C++ remains responsible for matching process
priority rules. I/O-priority rules can still overlap; inspect the effective
`/etc/gamemode.ini`, Ananicy rules and per-user GameMode settings. PPD and GameMode
may both influence CPU policy; a selected performance profile is distinct from a
game's active request. Check the actual governor/profile and logs instead of
assuming which tool wins. No NVIDIA clock overclock or unsafe GPU power setting
is introduced here.

```bash
gamemoded -t
# Start a game, then in a second terminal:
gamemoded -s
systemctl --user status gamemoded.service
journalctl --user -b -u gamemoded.service --no-pager
powerprofilesctl get
```

The diagnostic exercises GameMode's functionality and may briefly request policy
changes; it is not a purely read-only command. A successful test is not an FPS
benchmark. A game that exits immediately, such as `gamemoderun true`, only tests a
short request and may be gone before `-s` reports it.

## Steam versus terminal commands

In Steam: game → Properties → Launch Options:

```bash
gamemoderun %command%
```

For a hybrid laptop when you want NVIDIA rendering as well:

```bash
nvidia-offload gamemoderun %command%
```

`%command%` is Steam's launch-command substitution. **Do not type it literally in
a terminal.** Independent applications use their real executable and arguments:

```bash
gamemoderun your-game --your-game-option
nvidia-offload your-game
nvidia-offload gamemoderun your-game
```

Replace `your-game` with an installed game/launcher. The existing convenience
`game-on-nvidia your-game` runs `nvidia-offload` only; add GameMode explicitly with
`game-on-nvidia gamemoderun your-game` if wanted. Applications or launchers inside
sandboxes may need their own runtime integration; a host wrapper cannot ensure
those processes inherit every setting.

MangoHud is enabled as an available overlay, **not** forced for the whole session.
For supported games, `mangohud gamemoderun %command%` is a possible Steam option;
on a hybrid setup prefix with `nvidia-offload` if required. Validate the game's
rendering API/launcher before adding several wrappers at once.

## The original AMD + NVIDIA laptop

The user reports an AMD Ryzen 7 260 with Radeon 780M integrated graphics and an
RTX 5050, with these previously verified runtime observations:

| Item | Reported value / source configuration |
| --- | --- |
| PRIME offload | `hardware.nvidia.prime.offload.enable = true` |
| PRIME sync | `hardware.nvidia.prime.sync.enable = false` reported; module does not enable sync |
| Wrapper | `nvidia-offload` reported available; `enableOffloadCmd = true` in the module |
| Driver | `595.71.05` reported by the user; this audit did not run `nvidia-smi` on the laptop |
| Integrated PCI ID | `PCI:5@0:0:0` in `hosts/nixos/gpu.nix` |
| NVIDIA PCI ID | `PCI:1@0:0:0` in `hosts/nixos/gpu.nix` |
| Kernel modules | NVIDIA open modules enabled for this RTX 50-series configuration |

The module does not explicitly pin `595.71.05`; the locked Nixpkgs and selected
kernel determine the driver package. Confirm the built version before changing
inputs. The desktop can render on the iGPU while selected applications offload to
the discrete GPU. This can reduce unnecessary dGPU use, but actual runtime power
suspension depends on hardware, driver, displays and processes; it is not promised
by the offload flag alone.

```bash
nix eval --json .#nixosConfigurations.nixos.config.hardware.nvidia.prime.offload.enable
nix eval --json .#nixosConfigurations.nixos.config.hardware.nvidia.prime.sync.enable
nix eval --raw .#nixosConfigurations.nixos.config.hardware.nvidia.package.version
command -v nvidia-offload
nvidia-smi
nvidia-offload glxinfo -B   # if glxinfo has been installed for diagnosis
```

`nvidia-smi` shows driver/device/process information; sampling it can itself wake
the GPU. A game's process may not always appear the way its launcher does. Use a
renderer's own device report or Vulkan/GL diagnostics when GPU selection remains
uncertain. Laptop display wiring and external monitors can affect which GPU is
required. Do not enable PRIME sync and offload simultaneously without deliberately
redesigning the graphics setup.

## Hardware choices for other computers

Generated hosts use `my.machine.graphics`. NVIDIA-specific configuration is inside
NVIDIA-only conditions; it is not unconditionally activated for Intel/AMD machines.
The old laptop's `my.hardware.gpu` switch is specifically for **hybrid NVIDIA**,
not a generic switch that every computer must turn on.

| Hardware | Generator selection | What is configured | Typical Steam launch option |
| --- | --- | --- | --- |
| Intel integrated laptop/desktop | `--graphics intel` | Mesa graphics; kernel detects Intel; no NVIDIA driver or wrapper | `gamemoderun %command%` if GameMode enabled |
| AMD integrated laptop | `--graphics amd` | Mesa graphics; kernel detects AMD; no NVIDIA | `gamemoderun %command%` |
| AMD discrete desktop | `--graphics amd` | Same generic AMD graphics base; no NVIDIA PRIME | `gamemoderun %command%` |
| Intel + NVIDIA hybrid | `--graphics intel-nvidia` plus actual bus IDs | Reusable PRIME offload module, Intel vendor choice | `nvidia-offload gamemoderun %command%` for dGPU |
| AMD + NVIDIA hybrid | `--graphics amd-nvidia` plus actual bus IDs | Reusable PRIME offload module, AMD vendor choice | `nvidia-offload gamemoderun %command%` for dGPU |
| NVIDIA-only desktop | `--graphics nvidia` | NVIDIA driver, modesetting; **no PRIME offload wrapper needed** | `gamemoderun %command%` |
| VM/minimal without GPU requirements | `--graphics none --desktop minimal` | No selected hardware graphics stack | No GPU/GameMode wrapper by default |

Add `--gaming` to install the new profile's Steam/GameMode integration. Without
that flag, the launch options requiring GameMode are not applicable. The new
profile does not import Ananicy or the laptop's performance tuning automatically.
Intel/AMD-only hosts do not need an `nvidia-offload` command. PRIME offloading is
for selecting between a rendering iGPU and NVIDIA dGPU; a single-GPU desktop does
not need that selection. Choosing among multiple AMD/Intel devices can require
Mesa `DRI_PRIME` selection, which is separate and must match the actual hardware.

For hybrid generation, inspect `lspci -Dnn` on the new computer. Convert PCI bus
numbers to decimal for NixOS: `0000:0a:00.0` corresponds to `PCI:10@0:0:0`.
Do not reuse the laptop IDs just because the GPU models are similar.

Example generator arguments, **using illustrative bus IDs only**:

```bash
bash scripts/new-host.sh --host hybridpc --username alice --hardware /tmp/hardware-configuration.nix \
  --root-fs btrfs --graphics intel-nvidia --desktop hyprland --gaming \
  --integrated-bus-id PCI:0@0:2:0 --nvidia-bus-id PCI:1@0:0:0
```

Open NVIDIA modules require supported hardware. `--closed-nvidia` selects closed
kernel modules for a deliberately checked hardware/driver combination; it does
**not** choose a legacy NVIDIA driver branch automatically. Older unsupported
cards require a manually reviewed driver package, and a successful evaluation
cannot establish that an old card works. Secure Boot module signing and unusual
mux/external-GPU arrangements are outside automatic installation support.

## Validate a change

Build first, then reboot after kernel/driver changes. Check display login, native
resolution, external monitors, Vulkan/GL device selection, suspend/resume and
battery behavior on the real computer. Compare repeatable runs of the same game,
resolution, settings and thermal/power state to judge an optimization. Track frame
times as well as average FPS. Do not treat installed helper packages as evidence
that performance improved.

References: [GameMode](https://github.com/FeralInteractive/gamemode),
[upstream configuration example](https://github.com/FeralInteractive/gamemode/blob/master/example/gamemode.ini),
[NixOS NVIDIA guidance](https://wiki.nixos.org/wiki/NVIDIA).
