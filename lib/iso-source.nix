# Defence in depth for direct Nix builds. The Python builder also checks file
# contents and constructs a separate Git-tracked-only snapshot before invoking Nix.
{ lib, source }:
let
  root = toString source;
  roots = [ "assets" "home" "hosts" "iso-configs" "lib" "modules" "scripts" "tests" ];
  rootFiles = [ "flake.nix" "flake.lock" "README.md" ".gitignore" ];
  deniedDirs = [ ".git" ".ssh" ".gnupg" ".aws" ".azure" ".config" "private-keys-v1.d" "secrets" "credentials" "node_modules" "__pycache__" ];
  deniedName = name:
    builtins.elem name [ ".env" "credentials" "secring.gpg" "authorized_keys" "known_hosts" ]
    || lib.hasPrefix ".env." name
    || builtins.match "(id_(rsa|dsa|ecdsa|ed25519)|ssh_host_.*_key)(\\.pub)?" name != null
    || builtins.match ".*\\.(key|pem|p12|pfx|gpg|asc|age|kdbx)" name != null;
in
builtins.path {
  name = "nixos-public-iso-source";
  path = source;
  filter = path: type:
    let
      relative = lib.removePrefix (root + "/") (toString path);
      parts = lib.splitString "/" relative;
      name = builtins.baseNameOf path;
    in
    toString path == root || (
      !(lib.any (part: builtins.elem part deniedDirs) parts)
      && !deniedName name && type != "symlink"
      && (builtins.elem (builtins.head parts) roots || builtins.elem relative rootFiles)
    );
}
