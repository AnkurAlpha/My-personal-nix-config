# New-host templates and generator

Use the [host management guide](../../docs/HOSTS.md) and
[universal installation guide](../../docs/INSTALLATION.md).

After generating hardware on the actual target computer:

```bash
sudo nixos-generate-config --root /mnt --show-hardware-config > /tmp/hardware-configuration.nix
bash scripts/new-host.sh --host newpc --username alice \
  --hardware /tmp/hardware-configuration.nix --root-fs btrfs --graphics amd
git add hosts/newpc
nix eval --raw .#nixosConfigurations.newpc.config.networking.hostName
nix build --no-link .#nixosConfigurations.newpc.config.system.build.toplevel
```

The generator never installs or overwrites a different existing host. It validates
names, requires actual hardware data and writes one complete new host directory.
`lib/hosts.nix` automatically discovers directories with `configuration.nix`, so
no manual flake edit is needed. Reserved laptop and ISO outputs remain separate.

`new-host.nix.example` is an inactive manual reference, not a registered host.
Copy it only into a new host directory, add that target's hardware file and review
its username/graphics/boot/storage settings. The old laptop's hardware file is
never a portable template. Passwords are set locally with `passwd`, not in Git.

`nix-fleet hosts`, `nix-fleet iso-build`, and `nix-fleet template` remain available
on the original laptop. ISO builds do not flash a USB or install a machine.
