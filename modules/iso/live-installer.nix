# Reusable live-media defaults. No installed-host hardware or account is imported.
{ config, lib, pkgs, isoSource, ... }:
let
  cfg = config.my.iso;
  genericFiles = lib.optionalAttrs (cfg.desktop == "hyprland") {
    "hypr/hyprland.lua" = pkgs.writeText "live-hyprland.lua" ''
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      hl.config({ input = { kb_layout = "us" }, general = { layout = "dwindle" } })
      hl.on("hyprland.start", function() hl.exec_cmd("waybar") end)
      hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
      hl.bind("SUPER + D", hl.dsp.exec_cmd("wofi --show drun"))
      hl.bind("SUPER + Q", hl.dsp.window.close())
      for i = 1, 10 do
        hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = i }))
      end
    '';
    "waybar/config" = pkgs.writeText "live-waybar.json" (builtins.toJSON {
      layer = "top"; "modules-left" = [ "hyprland/workspaces" ];
      "modules-right" = [ "cpu" "memory" "clock" ]; clock.format = "{:%a %d %b %H:%M}";
    });
  };
  desktopFiles = genericFiles // cfg.desktopFiles;
  parentDirs = name: let parent = builtins.dirOf name;
    in if parent == "." then [] else (parentDirs parent) ++ [ parent ];
  configDirs = lib.unique (lib.concatMap parentDirs (builtins.attrNames desktopFiles));
  setup = pkgs.writeShellApplication {
    name = "nixos-setup";
    runtimeInputs = [ pkgs.git pkgs.python3 pkgs.nix pkgs.coreutils ];
    text = ''
      if [[ "$EUID" -eq 0 ]]; then
        echo 'Run nixos-setup as your live user; sudo is requested when installation needs it.' >&2
        exit 1
      fi
      work=$(mktemp -d "''${TMPDIR:-/tmp}/nixos-install-source.XXXXXX")
      cp -R --no-preserve=ownership ${isoSource}/. "$work/"
      chmod -R u+w "$work"
      git -C "$work" init --quiet -b main
      git -C "$work" add --all
      git -C "$work" -c user.name='ISO Snapshot' -c user.email=iso@localhost \
        -c commit.gpgsign=false commit --quiet -m 'Embedded ISO configuration snapshot'
      git -C "$work" remote add origin https://github.com/AnkurAlpha/My-personal-nix-config.git
      echo "Configuration source: $work"
      exec /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/env "PATH=$PATH" \
        ${pkgs.python3}/bin/python3 "$work/scripts/nixos_tools.py" install "$@"
    '';
  };
  livePassword = pkgs.writeShellApplication {
    name = "live-user-password";
    runtimeInputs = [ pkgs.shadow pkgs.coreutils ];
    text = builtins.readFile ./live-account-setup.sh;
  };
in {
  options.my.iso = {
    liveUsername = lib.mkOption {
      type = lib.types.addCheck (lib.types.strMatching "[a-z_][a-z0-9_-]{0,30}")
        (name: !(builtins.elem name [ "root" "nobody" "daemon" ]));
      default = "nixos";
      description = "Live account name. Its password is chosen interactively on every boot.";
    };
    desktop = lib.mkOption { type = lib.types.enum [ "minimal" "hyprland" "plasma" "gnome" ]; default = "minimal"; };
    sourceHost = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Host whose public desktop/app choices are exported."; };
    sourceUser = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Source host account supplying public desktop configuration."; };
    desktopFiles = lib.mkOption { type = lib.types.attrsOf lib.types.path; default = {}; internal = true; };
    passwordHash = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "\\$(y|6)\\$[./A-Za-z0-9$-]+");
      default = null; internal = true;
      description = "Optional throwaway live-password hash, supplied only through a temporary private build wrapper.";
    };
  };
  config = lib.mkMerge [
    {
      assertions = [ {
        assertion = lib.all (name: builtins.match "[A-Za-z0-9_./-]+" name != null
          && !lib.hasPrefix "/" name && !lib.hasInfix ".." name) (builtins.attrNames cfg.desktopFiles);
        message = "Live desktop config targets must be safe relative paths.";
      } ];
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      users.mutableUsers = true;
      # Replace the upstream passwordless live defaults, without baking a secret.
      users.users.nixos.enable = lib.mkForce (cfg.liveUsername == "nixos");
      users.users.root.initialHashedPassword = lib.mkForce "!";
      security.sudo.wheelNeedsPassword = lib.mkForce true;
      services.openssh.enable = lib.mkForce false;
      services.getty.autologinUser = lib.mkForce null;
      services.getty.helpLine = lib.mkForce ''
        Live user: ${cfg.liveUsername}; password ${if cfg.passwordHash == null then "chosen on this boot" else "chosen at image build time"}.
        Network: nmtui   Installation wizard: nixos-setup --install
        The wizard defaults to a plan without --install. Manual: /etc/nixos-iso-README.md
      '';
      environment.systemPackages = [ setup pkgs.git pkgs.python3 pkgs.btrfs-progs pkgs.parted pkgs.pciutils ];
      environment.etc."nixos-iso-README.md".source = isoSource + "/README.md";
      systemd.services.live-user-setup = {
        description = "Choose the live user's password on the local console";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-user-sessions.service" "systemd-tmpfiles-setup.service" ];
        before = [ "getty@tty1.service" "display-manager.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${livePassword}/bin/live-user-password ${cfg.liveUsername} ${if cfg.passwordHash == null then "boot" else "preset"}";
          StandardInput = "tty-force";
          StandardOutput = "tty";
          StandardError = "tty";
          TTYPath = "/dev/tty1";
          TTYReset = true;
          TTYVHangup = true;
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
      systemd.services."getty@" = {
        requires = [ "live-user-setup.service" ];
        after = [ "live-user-setup.service" ];
      };
      systemd.tmpfiles.rules = [ "d /home/${cfg.liveUsername}/.config 0700 ${cfg.liveUsername} users - -" ]
        ++ map (name: "d /home/${cfg.liveUsername}/.config/${name} 0700 ${cfg.liveUsername} users - -") configDirs
        ++ lib.mapAttrsToList (name: source: "C /home/${cfg.liveUsername}/.config/${name} - ${cfg.liveUsername} users - ${source}") desktopFiles;
    }
    {
      users.users.${cfg.liveUsername} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" "video" ];
        initialHashedPassword = lib.mkForce (if cfg.passwordHash == null then "!" else cfg.passwordHash);
      };
    }
    (lib.mkIf (cfg.desktop != "minimal") {
      programs.hyprland = lib.mkIf (cfg.desktop == "hyprland") { enable = true; withUWSM = true; xwayland.enable = true; };
      services.desktopManager.plasma6.enable = cfg.desktop == "plasma";
      services.desktopManager.gnome.enable = cfg.desktop == "gnome";
      services.displayManager.sddm = lib.mkIf (cfg.desktop != "gnome") { enable = true; wayland.enable = true; };
      services.displayManager.gdm.enable = cfg.desktop == "gnome";
      services.displayManager.autoLogin.enable = lib.mkForce false;
      systemd.services.display-manager = {
        requires = [ "live-user-setup.service" ];
        after = [ "live-user-setup.service" ];
      };
      security.rtkit.enable = true;
      services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
      environment.systemPackages = [ pkgs.kitty pkgs.wofi pkgs.waybar ];
    })
  ];
}
