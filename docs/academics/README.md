# Academics (NixOS + Home Manager)

## Switches

Edit `hosts/ankur-laptop/applications.nix`:

```nix
academics = {
  enable = true;
  matlab.enable = true;
  rstudio.enable = false;
};
```

The master switch (`enable`) must be true for either application to be present.
RStudio uses `pkgs.rstudio` and is disabled by default.

## MATLAB: important licensing and installation note

MATLAB is closed-source and is not downloaded or installed by this module.
The enabled MATLAB switch creates a `matlab` command using a Nix FHS environment.
You **must** separately download, install, and activate your properly licensed
MATLAB copy from MathWorks. See https://www.mathworks.com/downloads/ and
https://wiki.nixos.org/wiki/Matlab.

The launcher searches for `R20*` under:
- `~/MATLAB/`
- `~/.local/share/MATLAB/`
- `/usr/local/MATLAB/`
- `/opt/MATLAB/`

For any other location, set `MATLAB_ROOT` at runtime:

```sh
MATLAB_ROOT=/path/to/MATLAB/R20XXy matlab
```

The launcher is an FHS compatibility environment. Actual MATLAB startup may
require additional libraries depending on the installed release and add-ons.
NVIDIA/AMD graphics, Hyprland, existing PipeWire settings, and `/mnt/garuda`
are not modified. Do **not** copy licensed software into the Git repository.

## Verify

```sh
command -v matlab
matlab -help      # only works after separately installing MATLAB
command -v rstudio || echo 'RStudio is disabled'
```

## Activate

```sh
cd ~/nixos-config
nix --log-format raw build --no-link \
  --option max-jobs 1 --option cores 2 \
  ~/nixos-config#nixosConfigurations.ankur-laptop.config.system.build.toplevel
sudo -v
sudo nixos-rebuild switch --flake ~/nixos-config#ankur-laptop \
  --option max-jobs 1 --option cores 2
```
