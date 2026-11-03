{ lib, pkgs, ... }:
{
  # Garuda-inspired options without replacing the current kernel, GPU driver,
  # CPU governor, desktop services, or boot loader.

  # Interrupt distribution across a multicore CPU (not a new CPU scheduler).
  services.irqbalance.enable = lib.mkDefault true;

  # Apply desktop/background process priorities. GameMode has renice disabled
  # below so both daemons don't compete over game process nice values.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
  };

  # On-demand per-game optimizations; do not force NVIDIA GPU clocks or an
  # always-on CPU performance governor, which would hurt battery/thermals.
  programs.gamemode.enable = lib.mkDefault true;
  programs.gamemode.enableRenice = lib.mkDefault false;
  programs.gamemode.settings.general.renice = lib.mkDefault 0;

  # Existing Btrfs compression, monthly scrub, and power profiles stay intact.
  # Periodic NVMe TRIM is safe; keep controller's low-overhead IO scheduler.
  services.fstrim.enable = lib.mkDefault true;
  hardware.block.scheduler."nvme[0-9]*" = lib.mkDefault "none";

  # Fast compressed swap under memory pressure; no disk swap partition needed.
  zramSwap.enable = lib.mkDefault true;
  zramSwap.algorithm = lib.mkDefault "zstd";
  zramSwap.memoryPercent = lib.mkDefault 50;
}
