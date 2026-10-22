# Reproducible development environments

The existing `my.apps.development` options still control globally installed
compilers and tools. This addition provides **project-scoped**, flake-pinned
language shells without changing existing Fish, Direnv or nix-direnv settings.

## Switches

Edit `hosts/ankur-laptop/dev-environments.nix`. The top-level `enable` flag
disables all new development shells. Every language has its own `.enable` flag.
`helper.enable` toggles the Home Manager `nix-dev` command.

After changing switches, stage and commit the change before running a flake
command so Nix sees the updated settings in the Git-backed source tree.

## Usage

```bash
nix-dev list
nix-dev cpp
nix-dev python -- python --version
nix develop ~/nixos-config#rust
```

The first use of a shell may download/build packages. No changes to your
normal system profile are necessary.

## Using with existing Direnv + nix-direnv

In an *independent project* directory, review then create `.envrc`:

```bash
printf 'use flake "%s/nixos-config#cpp"\n' "$HOME" > .envrc
direnv allow .
```

This makes that independent project use the C/C++ shell from your NixOS flake.
Review `.envrc` content before authorizing; it can execute shell code. The
example uses your local config path, so for a shared project, a project-local
flake and `flake.lock` are preferable to this machine-specific path.

This installer never writes into `/mnt/garuda`, never changes Fish/Direnv
integration, and never updates pinned flake inputs.
