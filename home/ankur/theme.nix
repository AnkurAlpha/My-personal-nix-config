{ pkgs, ... }:

{
  gtk = {
    enable = true;

    theme = {
      name = "Sweet-Dark";
      package = pkgs.sweet;
    };

    iconTheme = {
      name = "BeautyLine";
      package = pkgs.beauty-line-icon-theme;
    };
  };

    home.pointerCursor = {
    enable = true;
    name = "Sweet-cursors";
    size = 24;

    gtk.enable = true;
    x11.enable = true;

    package = pkgs.runCommand "garuda-sweet-cursors" {} ''
      mkdir -p "$out/share/icons"
      cp -r ${./themes/Sweet-cursors} \
        "$out/share/icons/Sweet-cursors"
    '';
  };
}
