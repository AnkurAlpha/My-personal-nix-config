# Hardware-neutral base for NEW hosts. Never imported by the existing laptop.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.machine;
  hybrid = builtins.elem cfg.graphics [ "amd-nvidia" "intel-nvidia" ];
  nvidia = hybrid || cfg.graphics == "nvidia";
in {
  imports = [ ./portable.nix ../hardware/nvidia-hybrid.nix ];
  options.my.machine = {
    username = lib.mkOption { type = lib.types.strMatching "[a-z_][a-z0-9_-]*"; };
    desktop = lib.mkOption { type = lib.types.enum [ "minimal" "hyprland" ]; default = "minimal"; };
    graphics = lib.mkOption {
      type = lib.types.enum [ "none" "intel" "amd" "intel-nvidia" "amd-nvidia" "nvidia" ];
      default = "none";
    };
    integratedBusId = lib.mkOption { type = lib.types.str; default = ""; };
    nvidiaBusId = lib.mkOption { type = lib.types.str; default = ""; };
    nvidiaOpen = lib.mkOption { type = lib.types.bool; default = true; description = "Open NVIDIA kernel modules; check GPU support before choosing."; };
    gaming.enable = lib.mkEnableOption "Steam and GameMode on this new machine";
    bluetooth.enable = lib.mkEnableOption "Bluetooth on hardware that provides it";
    powerProfiles.enable = lib.mkEnableOption "power-profiles-daemon (no competing power managers)";
  };
  config = lib.mkMerge [
    {
      networking.networkmanager.enable = true;
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      my.profiles.portable = {
        enable = true;
        packages.git.enable = true;
        packages.curl.enable = true;
        packages.vim.enable = true;
      };
      programs.nh = { enable = true; flake = "/etc/nixos-config"; };
      users.users.${cfg.username} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" ];
        # Passwords are set locally with passwd after nixos-install.
      };
      hardware.bluetooth.enable = cfg.bluetooth.enable;
      services.power-profiles-daemon.enable = cfg.powerProfiles.enable;
      assertions = [ {
        assertion = !cfg.powerProfiles.enable ||
          !(config.services.tlp.enable || config.services.auto-cpufreq.enable || config.services.tuned.enable);
        message = "Use only one power policy backend on a generated machine.";
      } ];
    }
    (lib.mkIf (cfg.graphics != "none") {
      hardware.graphics = { enable = true; enable32Bit = lib.mkDefault cfg.gaming.enable; };
    })
    (lib.mkIf hybrid {
      my.hardware.gpu = {
        enable = true;
        integratedVendor = if cfg.graphics == "amd-nvidia" then "amd" else "intel";
        inherit (cfg) integratedBusId nvidiaBusId;
        openKernelModules = cfg.nvidiaOpen;
      };
    })
    (lib.mkIf (cfg.graphics == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = { open = cfg.nvidiaOpen; modesetting.enable = true; nvidiaSettings = true; };
    })
    (lib.mkIf nvidia { nixpkgs.config.allowUnfree = lib.mkDefault true; })
    (lib.mkIf cfg.gaming.enable {
      nixpkgs.config.allowUnfree = lib.mkDefault true;
      programs.steam.enable = true;
      programs.gamemode.enable = true;
    })
    (lib.mkIf (cfg.desktop == "hyprland") {
      programs.hyprland = { enable = true; withUWSM = true; xwayland.enable = true; };
      services.displayManager.sddm = { enable = true; wayland.enable = true; };
      security.rtkit.enable = true;
      services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${cfg.username} = {
          home.username = cfg.username;
          home.homeDirectory = "/home/${cfg.username}";
          home.stateVersion = config.system.stateVersion;
          programs.home-manager.enable = true;
          programs.kitty.enable = true;
          programs.wofi.enable = true;
          # A minimal Lua session using this repository's pinned Hyprland API.
          # The personal laptop's keybindings, Waybar and paths are not copied.
          xdg.configFile."hypr/hyprland.lua".text = ''
            hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
            hl.config({ input = { kb_layout = "us" }, general = { layout = "dwindle" } })
            hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
            hl.bind("SUPER + D", hl.dsp.exec_cmd("wofi --show drun"))
            hl.bind("SUPER + Q", hl.dsp.window.close())
            for i = 1, 10 do
              hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = i }))
            end
          '';
        };
      };
    })
  ];
}
