# RTX 5050 Laptop: integrated GPU for desktop + NVIDIA via PRIME offload.
# Enable/disable in hosts/ankur-laptop/gpu.nix.
{ config, lib, ... }:
let
  cfg = config.my.hardware.gpu;
in {
  options.my.hardware.gpu = {
    enable = lib.mkEnableOption "hybrid RTX 5050 GPU configuration";
    nvidiaBusId = lib.mkOption { type = lib.types.str; default = ""; };
    integratedBusId = lib.mkOption { type = lib.types.str; default = ""; };
    integratedVendor = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" ];
      default = "amd";
    };
  };

  config = lib.mkIf cfg.enable {
    # NVIDIA userspace is proprietary even with the open kernel module.
    nixpkgs.config.allowUnfree = lib.mkDefault true;
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    services.xserver.videoDrivers = [
      (if cfg.integratedVendor == "amd" then "amdgpu" else "modesetting")
      "nvidia"
    ];
    hardware.nvidia = {
      # Blackwell/RTX 50-series: use NVIDIA's open kernel modules.
      open = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      prime = {
        nvidiaBusId = cfg.nvidiaBusId;
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      } // (if cfg.integratedVendor == "amd" then {
        amdgpuBusId = cfg.integratedBusId;
      } else {
        intelBusId = cfg.integratedBusId;
      });
    };
  };
}
