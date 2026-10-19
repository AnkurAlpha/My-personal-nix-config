{ ... }:

{
  xdg.configFile."wofi/config".source =
    ./wofi/config;

  xdg.configFile."wofi/style.css".source =
    ./wofi/style.css;

  xdg.configFile."wofi/style.widgets.css".source =
    ./wofi/style.widgets.css;
}
