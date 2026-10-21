{ pkgs, ... }:
let
  bar = pkgs.nwg-bar;
  icons = "${bar}/share/nwg-bar/images";
  items = [
    {
      label = "_Lock screen";
      exec = "${pkgs.hyprlock}/bin/hyprlock";
      icon = "${icons}/system-lock-screen.svg";
    }
    {
      label = "Suspen_d";
      exec = "systemctl suspend";
      icon = "${icons}/system-suspend.svg";
    }
    {
      label = "Logou_t";
      exec = "hyprctl dispatch exit";
      icon = "${icons}/system-log-out.svg";
    }
    {
      label = "_Reboot";
      exec = "systemctl reboot";
      icon = "${icons}/system-reboot.svg";
    }
    {
      label = "_Shutdown";
      exec = "systemctl -i poweroff";
      icon = "${icons}/system-shutdown.svg";
    }
  ];
in
{
  home.packages = [ bar ];

  xdg.configFile."nwg-bar/bar.json".text = builtins.toJSON items;

  # Separate non-destructive click test. Launch: nwg-bar -t test.json
  xdg.configFile."nwg-bar/test.json".text = builtins.toJSON [
    {
      label = "_Test click";
      exec = "${pkgs.libnotify}/bin/notify-send 'nwg-bar' 'Button clicks work!'";
      icon = "${icons}/system-lock-screen.svg";
    }
  ];

  # Garuda-inspired styling adapted to nwg-bar's GTK widget names.
  xdg.configFile."nwg-bar/style.css".text = ''
    /* Garuda nwgbar look, adapted to nwg-bar's GTK widget selectors. */
    window {
      background-color: rgba(0, 0, 0, 0.12);
    }

    #outer-box {
      margin: 0;
      padding: 0;
    }

    #inner-box {
      background-color: rgba(0, 0, 0, 0.70);
      border: none;
      border-radius: 5px;
      padding: 5px;
      margin: 20px;
      box-shadow: 0 0 50px rgba(255, 0, 0, 0.70);
    }

    button {
      background-color: transparent;
      background-image: none;
      border: none;
      border-radius: 4px;
      box-shadow: none;
      color: #eceff4;
      padding: 10px 8px;
      margin: 5px;
      font-family: "Product Sans", "Noto Sans", sans-serif;
      font-size: 16px;
    }

    button label {
      color: #eceff4;
      font-family: "Product Sans", "Noto Sans", sans-serif;
      font-size: 16px;
    }

    button image {
      background-color: transparent;
      -gtk-icon-shadow: none;
    }

    button:hover,
    button:focus {
      background-color: rgba(255, 0, 0, 0.50);
      border: none;
      box-shadow: none;
    }

    button:active {
      background-color: rgba(255, 0, 0, 0.65);
    }
  '';
}
