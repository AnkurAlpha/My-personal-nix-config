# Zellij configuration

`home/ankur/zellij.nix` enables Home Manager's Zellij module and installs this
`config.kdl` when both desktop and Zellij application switches are on.

The current personal Hyprland binding is Super + Enter (XKB keycode 36):

```lua
bind_exec(mainMod .. " + code:36", "kitty -e env SHELL=/run/current-system/sw/bin/fish zellij")
```

It is installed only when Kitty, Fish and Zellij flags are all enabled. Edit the
source Lua in `home/ankur/hyprland/hyprland.lua`, not the generated home file.
Edit `config.kdl` for multiplexer keybindings, panes and appearance, then rebuild.
See [Desktop and Home Manager](../../../docs/DESKTOP_AND_HOME_MANAGER.md).
