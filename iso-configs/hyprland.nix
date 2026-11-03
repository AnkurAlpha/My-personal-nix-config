# Portable Hyprland live environment; no personal laptop disks or GPU IDs.
{ ... }: {
  my.iso = { liveUsername = "nixos"; desktop = "hyprland"; };
}
