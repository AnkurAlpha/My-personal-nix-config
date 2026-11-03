{ config, lib, ... }:
{
  # Home Manager controls Fish, but Kitty is NOT enabled through HM here.
  # Preserve the existing shell prompt, plugins, aliases and shortcuts.
  home-manager.users.${config.my.user.name}.programs.fish.interactiveShellInit = lib.mkAfter ''
    # Garuda-inspired dark pastel shell syntax colors.
    set -g fish_color_normal cdd6f4
    set -g fish_color_command 89b4fa
    set -g fish_color_keyword cba6f7
    set -g fish_color_param f5c2e7
    set -g fish_color_quote a6e3a1
    set -g fish_color_error f38ba8
    set -g fish_color_comment 7f849c
    set -g fish_color_operator 94e2d5
    set -g fish_color_search_match --background=45475a
  '';

  # Kitty officially loads /etc/xdg/kitty/kitty.conf as lower-priority
  # system-wide defaults; existing personal kitty.conf takes precedence.
  # This does NOT enable Kitty in Home Manager or overwrite ~/.config.
  environment.etc."xdg/kitty/kitty.conf".text = ''
    foreground #cdd6f4
    background #1e1e2e
    selection_foreground #1e1e2e
    selection_background #f5e0dc
    cursor #f5e0dc
    color0 #45475a
    color1 #f38ba8
    color2 #a6e3a1
    color3 #f9e2af
    color4 #89b4fa
    color5 #f5c2e7
    color6 #94e2d5
    color7 #bac2de
    color8 #585b70
    color9 #f38ba8
    color10 #a6e3a1
    color11 #f9e2af
    color12 #89b4fa
    color13 #f5c2e7
    color14 #94e2d5
    color15 #a6adc8
  '';
}
