{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/iso/installer-features.nix
    ../../modules/iso/live-installer.nix
  ];
  # Independent live installer, NOT a snapshot/clone of the laptop's root FS.
  my.iso.features = {
    enable = true;
    packages.git.enable = true;
    packages.neovim.enable = true;
    packages.tmux.enable = true;
    packages.diskTools.enable = true;
    packages.ripgrep.enable = false;
  };
  # live-installer replaces upstream account defaults with a chosen live account
  # and an interactive password setup. Installed credentials are chosen separately.
}
