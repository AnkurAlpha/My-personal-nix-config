# Reusable live-media defaults. No installed-host hardware or account is imported.
{ config, lib, pkgs, isoSource, ... }:
let
  cfg = config.my.iso;
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
  livePassword = pkgs.writeShellScript "live-user-password" ''
    if [ -e /run/live-account-ready ]; then exit 0; fi
    printf '\nSet a password for live account %s.\n' ${lib.escapeShellArg cfg.liveUsername}
    printf 'This live-session password is separate from the installed account password.\n'
    export LC_ALL=C
    while true; do
      if ${pkgs.shadow}/bin/passwd ${lib.escapeShellArg cfg.liveUsername}; then
        status="$(${pkgs.shadow}/bin/passwd -S ${lib.escapeShellArg cfg.liveUsername})"
        case "$status" in ${lib.escapeShellArg cfg.liveUsername}" P "*) break ;; esac
      fi
      printf '\nSet a non-empty usable password to finish live-session setup.\n'
    done
    ${pkgs.coreutils}/bin/touch /run/live-account-ready
  '';
in {
  options.my.iso = {
    liveUsername = lib.mkOption {
      type = lib.types.addCheck (lib.types.strMatching "[a-z_][a-z0-9_-]{0,30}")
        (name: !(builtins.elem name [ "root" "nobody" "daemon" ]));
      default = "nixos";
      description = "Live account name. Its password is chosen interactively on every boot.";
    };
    desktop = lib.mkOption { type = lib.types.enum [ "minimal" "hyprland" ]; default = "minimal"; };
  };
  config = lib.mkMerge [
    {
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      users.mutableUsers = true;
      # Replace the upstream passwordless live defaults, without baking a secret.
      users.users.nixos.enable = lib.mkForce (cfg.liveUsername == "nixos");
      users.users.root.initialHashedPassword = lib.mkForce "!";
      security.sudo.wheelNeedsPassword = lib.mkForce true;
      services.openssh.enable = lib.mkForce false;
      services.getty.autologinUser = lib.mkForce null;
      services.getty.helpLine = lib.mkForce ''
        Live user: ${cfg.liveUsername}; password chosen on this boot.
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
          ExecStart = "${livePassword}";
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
    }
    {
      users.users.${cfg.liveUsername} = {
        isNormalUser = true;
        extraGroups = [ "wheel" "networkmanager" "video" ];
        initialHashedPassword = lib.mkForce "!";
      };
    }
    (lib.mkIf (cfg.desktop == "hyprland") {
      programs.hyprland = { enable = true; withUWSM = true; xwayland.enable = true; };
      services.displayManager.sddm = { enable = true; wayland.enable = true; };
      services.displayManager.autoLogin.enable = lib.mkForce false;
      systemd.services.display-manager = {
        requires = [ "live-user-setup.service" ];
        after = [ "live-user-setup.service" ];
      };
      security.rtkit.enable = true;
      services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
      environment.systemPackages = [ pkgs.kitty pkgs.wofi pkgs.waybar ];
      # Seed the known user config path; do not rely on compositor-global fallback.
      systemd.tmpfiles.rules = [
        "d /home/${cfg.liveUsername}/.config 0700 ${cfg.liveUsername} users - -"
        "d /home/${cfg.liveUsername}/.config/hypr 0700 ${cfg.liveUsername} users - -"
        "C /home/${cfg.liveUsername}/.config/hypr/hyprland.lua 0644 ${cfg.liveUsername} users - /etc/xdg/hypr/hyprland.lua"
        "d /home/${cfg.liveUsername}/.config/waybar 0700 ${cfg.liveUsername} users - -"
        "C /home/${cfg.liveUsername}/.config/waybar/config 0644 ${cfg.liveUsername} users - /etc/xdg/waybar/config"
      ];
      environment.etc."xdg/hypr/hyprland.lua".text = ''
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
      environment.etc."xdg/waybar/config".text = builtins.toJSON {
        layer = "top";
        "modules-left" = [ "hyprland/workspaces" ];
        "modules-right" = [ "cpu" "memory" "clock" ];
        clock.format = "{:%a %d %b %H:%M}";
      };
    })
  ];
}
