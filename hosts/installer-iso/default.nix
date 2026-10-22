{ modulesPath, ... }: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/iso/installer-features.nix
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
  # The upstream minimal installer supplies its own installer boot and users.
  # No personal Wi-Fi connections, credentials, NVIDIA config, disks, or SSH keys.
}
