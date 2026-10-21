{ config, lib, pkgs, ... }:
let
  cfg = config.my.system.maintenance;
  health = pkgs.writeShellScriptBin "nix-health" ''
    #!${pkgs.runtimeShell}
    echo "=== System and kernel ==="
    ${pkgs.coreutils}/bin/uname -a
    echo
    echo "=== Root filesystem and Garuda reference (read-only) ==="
    ${pkgs.util-linux}/bin/findmnt -T / -o TARGET,SOURCE,FSTYPE,OPTIONS || true
    ${pkgs.util-linux}/bin/findmnt --mountpoint /mnt/garuda -o TARGET,SOURCE,FSTYPE,OPTIONS || true
    echo
    echo "=== Filesystem usage ==="
    ${pkgs.coreutils}/bin/df -h / /nix || true
    echo
    echo "=== Failed system services ==="
    ${pkgs.systemd}/bin/systemctl --failed --no-pager || true
    echo
    echo "=== Recent NixOS generations ==="
    if command -v nixos-rebuild >/dev/null 2>&1; then
      nixos-rebuild list-generations | ${pkgs.coreutils}/bin/tail -n 10 || true
    fi
    echo
    echo "=== No cleanup was performed ==="
  '';
in {
  options.my.system.maintenance = {
    enable = lib.mkEnableOption "system maintenance features";
    diagnostics.enable = lib.mkEnableOption "read-only nix-health command";
    fstrim.enable = lib.mkEnableOption "periodic SSD trim (may affect other mounted filesystems)";
    btrfsScrub.enable = lib.mkEnableOption "periodic scrub of the NixOS root Btrfs filesystem";
    smartMonitoring.enable = lib.mkEnableOption "SMART health monitoring daemon";
    firmwareService.enable = lib.mkEnableOption "fwupd service (does not auto-install firmware)";
    storeOptimisation.enable = lib.mkEnableOption "automatic store deduplication without garbage collection";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = lib.optionals cfg.btrfsScrub.enable [
        {
          assertion = ((config.fileSystems."/" or {}).fsType or "") == "btrfs";
          message = "my.system.maintenance.btrfsScrub requires the NixOS root filesystem to be Btrfs. It will not scrub /mnt/garuda.";
        }
      ];
    }
    (lib.mkIf cfg.diagnostics.enable {
      environment.systemPackages = [ health ];
    })
    (lib.mkIf cfg.fstrim.enable {
      services.fstrim.enable = true;
    })
    (lib.mkIf cfg.btrfsScrub.enable {
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [ "/" ];
      };
    })
    (lib.mkIf cfg.smartMonitoring.enable {
      services.smartd.enable = true;
    })
    (lib.mkIf cfg.firmwareService.enable {
      services.fwupd.enable = true;
    })
    (lib.mkIf cfg.storeOptimisation.enable {
      nix.optimise.automatic = true;
      nix.optimise.dates = [ "Sun 04:00" ];
    })
  ]);
}
