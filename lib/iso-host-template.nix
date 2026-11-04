# Export public desktop/app choices into a separate live OS. Never extend the
# selected host's system with installer modules: its mounts/users/services stay out.
{ host }:
{ config, lib, pkgs, ... }:
let
  cfg = config.my.iso;
  original = host.config;
  normalUsers = builtins.attrNames (lib.filterAttrs (_: user: user.isNormalUser or false) original.users.users);
  primary = original.my.user.name or (if builtins.length normalUsers == 1 then builtins.head normalUsers else null);
  sourceUser = if cfg.sourceUser != null then cfg.sourceUser else primary;
  rebind = sourceUser == primary && lib.hasAttrByPath [ "my" "user" "name" ] host.options;
  rebound = if !rebind then host else host.extendModules {
    modules = [ ({ lib, ... }: lib.mkMerge [
      { my.user = {
          name = lib.mkForce cfg.liveUsername;
          homeDirectory = lib.mkForce "/home/${cfg.liveUsername}";
          description = lib.mkForce "Live user";
          git.name = lib.mkForce "Live user";
          git.email = lib.mkForce "";
        };
      }
      (lib.optionalAttrs (lib.hasAttrByPath [ "my" "machine" "username" ] host.options) {
        my.machine.username = lib.mkForce cfg.liveUsername;
      })
    ]) ];
  };
  selected = rebound.config;
  selectedUser = if rebind then cfg.liveUsername else sourceUser;
  homes = selected.home-manager.users or {};
  home = if selectedUser != null && builtins.hasAttr selectedUser homes then homes.${selectedUser} else null;
  oldHome = if home != null then home.home.homeDirectory else if sourceUser != null then "/home/${sourceUser}" else "";
  prefixes = [ "hypr/" "waybar/" "kitty/" "wofi/" "mako/" "nwg-dock-hyprland/" "nwg-drawer/" "nwg-bar/" "gtk-3.0/" "gtk-4.0/" "fontconfig/" "Kvantum/" "qt5ct/" "qt6ct/" "nvim/" ];
  allowed = name: builtins.match "[A-Za-z0-9_./-]+" name != null
    && !lib.hasInfix ".." name && lib.any (prefix: lib.hasPrefix prefix name) prefixes;
  publicFiles = if home == null then {} else lib.filterAttrs (name: file:
    allowed name && (file.enable or true) && file.source != null
  ) home.xdg.configFile;
  desktopFiles = lib.mapAttrs (name: file:
    if file.text != null then pkgs.writeTextFile {
      name = "live-" + lib.replaceStrings [ "/" ] [ "-" ] name;
      text = if oldHome == "" then file.text else lib.replaceStrings [ oldHome ] [ "/home/${cfg.liveUsername}" ] file.text;
      executable = file.executable == true;
    } else file.source
  ) publicFiles;
  desktop = if original.programs.hyprland.enable then "hyprland"
    else if original.services.desktopManager.plasma6.enable then "plasma"
    else if original.services.desktopManager.gnome.enable then "gnome" else "minimal";
  removable = original.my.system.storageFilesystems.removable.udiskieAutomount.enable or false;
  userPackages = if selectedUser != null then selected.users.users.${selectedUser}.packages or [] else [];
  nvidia = builtins.elem "nvidia" original.services.xserver.videoDrivers;
in {
  assertions = [ {
    assertion = sourceUser == null || builtins.elem sourceUser normalUsers;
    message = "The ISO source user must be a normal user of the selected host.";
  } ];
  my.iso.desktop = lib.mkDefault desktop;
  my.iso.desktopFiles = desktopFiles;
  networking.hostName = lib.mkForce ((lib.substring 0 57 original.networking.hostName) + "-live");
  nixpkgs.config.allowUnfree = lib.mkDefault true;
  boot.kernelPackages = original.boot.kernelPackages;
  # Driver family and matching kernel packages are public choices. PRIME PCI bus
  # IDs, disk UUIDs, initrd secrets and installed-host boot settings are not copied.
  services.xserver.videoDrivers = lib.mkDefault original.services.xserver.videoDrivers;
  hardware.nvidia = lib.mkIf nvidia {
    package = lib.mkDefault original.hardware.nvidia.package;
    open = lib.mkDefault original.hardware.nvidia.open;
    modesetting.enable = true;
  };
  environment.systemPackages = lib.unique (selected.environment.systemPackages ++ userPackages
    ++ lib.optionals (home != null) home.home.packages ++ lib.optionals removable [ pkgs.udiskie ]);
  fonts.packages = original.fonts.packages;
  i18n.defaultLocale = lib.mkDefault original.i18n.defaultLocale;
  time.timeZone = lib.mkDefault original.time.timeZone;
  programs.steam.enable = original.programs.steam.enable;
  programs.gamemode.enable = original.programs.gamemode.enable;
  users.users.${cfg.liveUsername}.extraGroups = lib.optional original.programs.gamemode.enable "gamemode";
  hardware.bluetooth.enable = original.hardware.bluetooth.enable;
  services.udisks2.enable = lib.mkIf removable true;
  services.gvfs.enable = lib.mkIf removable true;
  systemd.user.services.udiskie = lib.mkIf removable {
    description = "Live-session removable-drive automounter";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig.ExecStart = "${pkgs.udiskie}/bin/udiskie --no-tray";
  };
}
