# Declarative GTK + Qt appearance

Your existing `home/ankur/theme.nix` still owns:
- Sweet-Dark GTK2/3/4 configuration (GTK4/libadwaita may choose different visuals)
- BeautyLine icon package
- Sweet-cursors at 24px

This add-on creates:
- `modules/system/qt-appearance-options.nix` — feature option declarations
- `hosts/ankur-laptop/qt-appearance.nix` — per-feature switches
- `home/ankur/qt-appearance.nix` — Home Manager Qt5/Qt6 config

New Qt configuration uses qt5ct/qt6ct, the BeautyLine icon theme, and
Kvantum with its built-in dark `KvDark` style. Kvantum's compositing is
explicitly disabled to avoid some Hyprland/Qt6 crashes. This is not
pixel-identical to GTK Sweet-Dark, but it gives Qt apps a consistent dark look.
No Plasma/KWallet modules are enabled.

Switches (`hosts/ankur-laptop/qt-appearance.nix`):
- `my.system.qtAppearance.enable` — master; false disables all added Qt theming
- `qt5Settings.enable` — declarative Qt5 appearance config
- `qt6Settings.enable` — declarative Qt6 appearance config
- `kvantum.enable` — Kvantum dark widget style, else Qt Fusion fallback

No changes are made to `theme.nix`, Hyprland Lua, fonts, KWallet or your GPU.

After activation **log out/in** for QT environment variables to reach new apps.

Inspect:
```
printenv QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE
cat ~/.config/qt6ct/qt6ct.conf
cat ~/.config/Kvantum/kvantum.kvconfig
```

Note: Electron, browser, libadwaita, sandboxed Flatpak, and some KDE apps
have their own theming behavior, so not every application will look identical.
