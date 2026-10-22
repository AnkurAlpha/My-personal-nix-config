# Adding another NixOS host safely

This folder is only a reference. The installer will not register another
computer until you know its actual hardware, partitions and boot method.

1. Boot a NixOS live ISO on the *new* computer and partition it manually.
   **Check block device names carefully. Nothing here partitions drives.**
2. Run `sudo nixos-generate-config --root /mnt` on that computer after mounting
   the new system's root and boot partitions.
3. Create `hosts/NEW_HOST/` in your cloned Git repo; copy
   `new-host.nix.example` to `hosts/NEW_HOST/configuration.nix`.
4. Copy the freshly generated `hardware-configuration.nix` into that host
   directory. Never copy `hosts/ankur-laptop/hardware-configuration.nix`.
5. Adjust `networking.hostName`, `system.stateVersion`, bootloader,
   user credentials and host-specific packages for the new machine.
6. Register a NEW attribute in `flake.nix` using this pattern, without
   altering the existing `ankur-laptop` or `nixos` aliases:

   NEW_HOST = nixpkgs.lib.nixosSystem {
     system = "x86_64-linux";
     modules = [ ./hosts/NEW_HOST/configuration.nix ];
   };

7. Review and commit the changes, and run
   `sudo nixos-install --flake /path/to/repo#NEW_HOST` FROM THE LIVE ISO,
   after verifying the target filesystem mounts.

Do not publish passwords or private keys in your Git repo. A minimal installer
ISO is not an installed system; copying a laptop's configuration as-is to
another machine is unsafe due to bootloader, disk UUID and GPU differences.

Use `nix-fleet hosts`, `nix-fleet iso-build`, and `nix-fleet template` on your
original laptop. Building an ISO does not flash a USB or erase a drive.
