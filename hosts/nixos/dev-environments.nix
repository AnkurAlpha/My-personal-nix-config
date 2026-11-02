# Isolated per-project shells (not globally installed system packages).
# These settings are also read by the flake outputs. Change a switch, then
# git add/commit the changes before using nix develop from the Git flake.
{
  enable = true;
  helper.enable = true; # nix-dev wrapper installed in Home Manager
  repoPath = "/home/ankur/nixos-config";

  cpp.enable = true;
  python.enable = true;
  rust.enable = true;
  node.enable = true;
  java.enable = false;
  clang.enable = false;
  go.enable = false;
  fullstack.enable = false;
}
