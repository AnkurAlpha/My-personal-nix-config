# Desktop Customization (opt-in tools, no changes to desktop by default)

**All features are off** in `hosts/ankur-laptop/desktop-customization.nix`.
The master `enable` switch must also be true before any individual tool is added.

This module **does not replace** the existing:
- `home/ankur/theme.nix` (Sweet-Dark GTK, BeautyLine icons, Sweet cursor)
- `home/ankur/fonts.nix` (JetBrains Mono Nerd, Symbols, Ubuntu, Noto emoji)
- `home/ankur/hyprland/` (Hyprland Lua, Waybar, Mako, Wofi, wallpaper)

| Host switch | Optional package | Side effects when enabled |
|---|---|---|
| `gtkThemeEditor` | `nwg-look` | Adds editor only; saving in the GUI may update your live GTK settings |
| `qtThemeEditor` | `qt6ct` | Adds editor only; no QT_QPA_PLATFORMTHEME override |
| `iconThemes` | `papirus-icon-theme` | Additional icons, existing BeautyLine remains selected |
| `cursorThemes` | `bibata-cursors` | Additional cursors, existing Sweet cursor remains selected |
| `extraFonts` | `inter` | Font added without changing default font selection |
| `fontManager` | `font-manager` | Optional font management GUI |
| `colorPicker` | `hyprpicker` | Optional interactive Wayland picker |
| `wallpaperGui` | `waypaper` | Adds GUI only; no session autostart or replacement of wpaperd |
| `nightLightTool` | `hyprsunset` | Adds binary only, does not run the daemon |
| `screenshotAnnotator` | `swappy` | Adds editor only, no hotkey or screenshot pipeline replacement |
| `notificationCli` | `libnotify` | Adds `notify-send`, does not replace Mako |

To enable a tool, edit `hosts/ankur-laptop/desktop-customization.nix`:

```nix
my.system.desktopCustomization = {
  enable = true;
  colorPicker.enable = true;
  # Keep the other switches false.
};
```

Then apply with:

```sh
nh os build ~/nixos-config -H ankur-laptop
nh os switch ~/nixos-config -H ankur-laptop
```

No KDE Plasma/KWallet configuration is introduced. No auto-starting services,
wallpaper replacement, GTK/Qt theme modifications, or FIMLoom changes.
Reference mount `/mnt/garuda` is checked for path existence only; it is not modified.
