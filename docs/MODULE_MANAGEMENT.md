# Software and module management

Examples start in `~/nixos-config` on the original host `nixos`, unless a new-host
example says otherwise. Edit repository source files, not Home Manager's generated
symlinks. Build before activation. Keep a recovery generation and a source commit.

## Choose the right kind of change

| Need | Configuration owner | Example in this repository |
| --- | --- | --- |
| Binary for every user | NixOS `environment.systemPackages` | Diagnostic helpers in `modules/system/` |
| Binary for Ankur | HM `home.packages` or HM `programs.*` | `home/ankur/applications/utilities.nix` |
| System daemon/permissions | NixOS `services.*`, `programs.*`, users/groups | Steam, GameMode and Docker |
| User daemon | HM `services.*` or `systemd.user.*` | Hyprsunset, GPG agent, trash cleanup |
| App config in home | HM `xdg.configFile`, `home.file` or `programs.*` | Kitty raw file, Fish module, Waybar generated JSON |
| Tools for one project | `devShells`, `.envrc`, `nix develop` | `modules/development/dev-shells.nix` |
| One-off command | `nix shell` | Try a package without a declarative rebuild |

Installing `pkgs.docker` as a user package is not equivalent to enabling the Docker
daemon. Installing `pkgs.kitty` through `home.packages` is still Home Manager
package management even if `programs.kitty.enable` is false. Linux user data lives
outside the package and survives its removal.

## Install an application

### Existing application switch

Kate already has a declared flag and implementation. Change this line in
`hosts/nixos/applications.nix`:

```nix
utilities = {
  enable = true;
  kate.enable = true;
  # Retain the other existing choices.
};
```

Do not add a second `utilities = { ... };` alongside the existing one in the same
attribute set; edit the existing block. The implementation in
`home/ankur/applications/utilities.nix` uses
`add c.kate.enable [ pkgs.kdePackages.kate ]`.

```bash
git add hosts/nixos/applications.nix
nh os build . -H nixos
nh os test . -H nixos
nh os switch . -H nixos
git commit -m "Enable Kate"
```

### System-wide software

For a simple host-only package, replace the currently empty list in
`hosts/nixos/configuration.nix`:

```nix
environment.systemPackages = [ pkgs.tree ];
```

Do not append a duplicate assignment in the same file. Lists from different
modules merge, so adding `environment.systemPackages = [ pkgs.tree ];` in a new
imported module is also valid. System packages are distinct from
`users.users.ankur.packages`, which the root host currently leaves empty.

### User-only software

For a simple personal addition to `home/ankur/home.nix`:

```nix
home.packages = [ pkgs.tree ];
```

That root HM file already receives `pkgs`. Its imported modules can contribute
their own lists. For an existing implementation file, add to its current list:
for example, adding `pkgs.rsync` to `home/ankur/applications/development.nix`
requires deciding whether it shares an existing tool switch or deserves its own.
Do not add an unguarded package to a module whose category is meant to disable it.

### Add a new switch to an application category

To create `my.apps.utilities.tree.enable`:

1. Add `"tree"` to the utilities app-name list in
   `modules/applications/options.nix`.
2. Add `++ add c.tree.enable [ pkgs.tree ]` to the existing package expression in
   `home/ankur/applications/utilities.nix`.
3. Add `tree.enable = true;` within the existing `utilities` block in
   `hosts/nixos/applications.nix`.
4. Stage the changed files, evaluate/build, then activate.

The schema must be declared once. An undeclared option fails evaluation; a
misspelled package fails when its expression is evaluated. Use `nix search nixpkgs
'^tree$'` to find candidates, then check the pinned package if availability matters:

```bash
nix eval --impure --raw --expr '(let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.tree.version)'
```

`--impure` is used here only to resolve the local path in this expression, not to
make builds read arbitrary environment state. Installed software still comes from
the repository's locked inputs.

### Temporary packages and developer tools

```bash
nix shell nixpkgs#tree --command tree --version
nix shell nixpkgs#ripgrep nixpkgs#jq
nix develop .#cpp
nix develop .#python --command python --version
nix-dev list
```

The `nixpkgs` registry may differ from the flake's pin. Developer shells in this
repo use its locked Nixpkgs. Edit `hosts/nixos/dev-environments.nix` to enable a
language shell. Edit `modules/development/dev-shells.nix` to add shell packages.
No system switch is needed to use a changed dev shell, but rebuild the system if
changing whether the HM `nix-dev` helper itself is installed. See the
[Direnv guide](development-environments/README.md) before trusting `.envrc`.

### A service requiring NixOS integration

For Docker, enable both development and Docker in
`hosts/nixos/applications.nix`. `modules/applications/docker.nix` enables
`virtualisation.docker` and adds Ankur to `docker`. Build/switch and log out/in
before testing `docker info`. That group grants root-equivalent control. Removing
only a Docker client package does not disable its daemon or remove its data.
For PostgreSQL, CUPS, SSH, libvirtd and similar daemons, use their NixOS options and
read their option descriptions instead of merely adding a binary to HM.

## Completely disable software or module functionality

Set its per-app switch to `false`; set a category's master to `false` to disable
its guarded definitions. Check *all* providers:

```bash
rg -n 'vivaldi|firefox|signal-desktop|pkgs\.mpv|obs-studio' hosts modules home
nix eval --json .#nixosConfigurations.nixos.config.my.apps
nix eval --json .#nixosConfigurations.nixos.config.home-manager.users.ankur.home.packages --apply 'ps: map (p: p.pname or p.name) ps'
nix eval --json .#nixosConfigurations.nixos.config.environment.systemPackages --apply 'ps: map (p: p.pname or p.name) ps'
command -v vivaldi
readlink -f "$(command -v vivaldi)"
nix profile list
```

Vivaldi needs `internet.vivaldi` **and** `browsers.vivaldi` disabled; MPV/VLC/OBS
have `media` and `multimedia`; Signal has `internet` and `social`. Search also for
HM `programs.*`, NixOS services, per-user packages, temporary shells, imperative
profiles and dependency-provided executables. `command -v` describes the current
shell's PATH, which may still contain an old dev shell or profile.

Fish's HM appearance now follows the desktop/Fish flag, but the host's Fish login
shell is independently enabled in `hosts/nixos/shell-fish.nix`. Switching the login
shell to Bash requires editing that host module too, then a fresh login. Keep an
available login shell. Power-menu contents and startup are separately guarded;
Hyprland itself remains enabled even when the desktop application group is off.
Direnv, the trash timer and dev-environment helper have their own owners.

A module can be **imported but disabled**: option declarations still exist and its
conditional config adds nothing. Removing its import removes its declarations as
well; leftover assignments or HM readers can then fail with unknown-option errors.
For example, do not remove `modules/applications/options.nix` while importing HM
application files. Before removing a system option module, inspect matching
host selectors **and** all HM `osConfig` consumers.

Direct host modules such as `garuda-system-goodies.nix` have no custom master.
Disable the native options deliberately from an override module, or remove the
import after reviewing the effects and any remaining providers. Setting
`my.system.maintenance.fstrim.enable = false` does not turn off goodies' fstrim.
To disable ZRAM entirely, address both performance-tuning's ZRAM flag and the
Garuda goodies fallback. A single `zramSwap.enable = lib.mkForce false` is an
intentional final override, but document why it is necessary and inspect the
result. Do not use `mkForce` to hide an unexplained conflict.

Disabling a service does not delete its databases. Removing an app does not delete
`~/.config`, `~/.local/share`, browser profiles, saves or caches. Delete user data
only as a separate, explicitly chosen action after backup.

## Option priority and optional imports

| Expression | Use |
| --- | --- |
| `value = lib.mkDefault x;` | Baseline other hosts may override; priority 1000 |
| `value = x;` | Normal definition; priority 100 |
| `value = lib.mkForce x;` | Deliberate stronger override; priority 50 |
| `lib.mkIf cfg.enable { ...; }` | Include definitions only when enabled |
| `lib.mkBefore` / `lib.mkAfter` | Order merged list/string fragments; do not replace priority |

Smaller priority numbers win. Equal-ranked conflicting booleans/strings fail;
lists concatenate at the winning priority. The current host forces a null CPU
governor so PPD owns policy, and forces the Astronaut greeter theme. Setting a
normal performance governor or Elegant theme elsewhere cannot beat those.
Use `lib.optionals` for a package/import list whose condition is independent of
module evaluation. Avoid `imports = lib.optionals config.my... [...]` because
import resolution needs the eventual option declarations and can recurse.

## Create a reusable NixOS module

Create `modules/system/example-health.nix`:

```nix
{ config, lib, pkgs, ... }:
let cfg = config.my.system.exampleHealth;
in {
  options.my.system.exampleHealth = {
    enable = lib.mkEnableOption "local filesystem health report";
    timer.enable = lib.mkEnableOption "daily health report in the journal";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.tree ];
    systemd.services.example-health = {
      description = "Read-only filesystem usage report";
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      script = "${pkgs.coreutils}/bin/df -h / /nix";
    };
    systemd.timers.example-health = lib.mkIf cfg.timer.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = "daily"; Persistent = true; };
    };
  };
}
```

This is a teaching example, **not already enabled in the repo**. It writes only to
the journal and does not clean data. Import it once in the host's existing
`imports` list (`../../modules/system/example-health.nix` from `hosts/nixos/`), then
add the settings to that host:

```nix
my.system.exampleHealth = { enable = true; timer.enable = false; };
```

For a new generated host, use the same relative import alongside its hardware and
machine profile. To reuse it everywhere, import it from the relevant shared
profile only after deciding whether every profile should have the option schema.

```bash
git add modules/system/example-health.nix hosts/nixos/configuration.nix
nix-instantiate --parse modules/system/example-health.nix >/dev/null
nix eval --json .#nixosConfigurations.nixos.config.my.system.exampleHealth
nix flake check --no-build --no-update-lock-file
nix build --no-link .#nixosConfigurations.nixos.config.system.build.toplevel
nh os test . -H nixos
sudo systemctl start example-health
journalctl -u example-health --no-pager
```

A manual `start` is appropriate for this safe oneshot report. Enable the timer
only if wanted; then inspect `systemctl list-timers --all`. After satisfactory
runtime checks, switch and commit. Reboot is unnecessary for this service alone.

## Modify existing modules safely

Before editing an option, inspect its final value, declaration and definition
locations:

```bash
nix eval --json .#nixosConfigurations.nixos.options.zramSwap.memoryPercent.declarations
nix eval --json .#nixosConfigurations.nixos.options.zramSwap.memoryPercent.definitionsWithLocations --apply 'xs: map (x: { inherit (x) file value; }) xs'
nix eval --json .#nixosConfigurations.nixos.config.zramSwap.memoryPercent
```

For nested HM options, enter
`options.home-manager.users` carefully or inspect the source/HM manual; not every
nested dynamic submodule's options can be traversed using an ordinary attr path.
`rg 'OPTION|PACKAGE' hosts modules home` remains useful. Use `--show-trace` when
an evaluation error needs its definition context.

| Change | Edit here | What to check |
| --- | --- | --- |
| Package list | Corresponding `home/ankur/applications/*.nix` | Category guard, schema, other providers, package name |
| System service | `modules/system/<feature>.nix` plus host selector | Dependencies, firewall, restart effects, exclusive daemons |
| Hyprland | `home/ankur/hyprland/hyprland.lua`; flag prefix in `default.nix` | Keep Lua API/keybindings, `hyprctl configerrors`, reload after activation |
| Waybar | `waybar.nix` and `waybar/config.json`; CSS separately | `waybar.nix` overrides raw values; keep custom icons; don't edit generated `waybar/config` |
| Fish | `fish.nix`, `shell/default.nix`, Starship TOML or host colors | Multiple init fragments merge; open a new interactive shell |
| Gaming | `hosts/nixos/gaming.nix`, HM `applications/gaming.nix` | Native service versus wrapper, power/priority interactions |
| NVIDIA | `hosts/nixos/gpu.nix`, `modules/hardware/nvidia-hybrid.nix` | Real decimal PCI IDs, open-module compatibility, offload vs sync, reboot |
| Another computer | `hosts/NAME/configuration.nix`, `my.machine.*` | Own hardware, username, bootloader and mounts; never copy laptop values blindly |

Review `git diff`, build, test the affected behavior and commit. A new option does
not need a full system rewrite. Keep changes narrow enough that rollback has a
clear source commit to revert.
