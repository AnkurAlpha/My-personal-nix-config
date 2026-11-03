# Desktop and Home Manager ownership

The laptop's `flake.nix` integrates HM into NixOS and imports `home/ankur/home.nix`.
The standalone `ankur@garuda` output is separate and currently minimal; do not
activate the laptop's `osConfig`-dependent modules as a standalone Garuda home.

| Component | Source files | Activation and details |
| --- | --- | --- |
| Hyprland/UWSM/XWayland | `modules/hyprland.nix` | System compositor/session integration remains enabled independently of desktop app flags |
| Hyprland behavior | `home/ankur/hyprland/default.nix`, `hyprland.lua` | Nix generates an `app_enabled` prefix; raw Lua keeps personal keybindings/scale; no generated file edits |
| Waybar | `hyprland/waybar.nix`, `waybar/config.json`, `waybar/style.css` | HM generates `~/.config/waybar/config`; the raw repository `waybar/config` is a retained legacy asset |
| Power-profile widget | `waybar.nix`, `waybar/scripts/power_profile_menu.sh` | PPD module inserted before battery; left-click cycles supported profiles, right-click uses Wofi |
| Power menu | `hyprland/nwg-bar.nix` | Imported via HM sharedModules, guarded by desktop/powerMenu; `nwg-bar -t test.json` opens notification-only test |
| Kitty | `applications/desktop.nix`, `hyprland/kitty.nix`, `hyprland/kitty/kitty.conf` | HM package + raw config, **not** `programs.kitty`; user palette overrides system Garuda defaults |
| Fish login shell | `hosts/nixos/shell-fish.nix` | System Fish remains login shell independently of HM appearance flags |
| Fish aliases/init | `fish.nix`, `shell/default.nix`, `hosts/nixos/garuda-terminal-goodies.nix` | `ll`, `nrs/nrb/nri`, Starship, Fastfetch, syntax colors; init fragments merge |
| Prompt and system display | `shell/starship.toml`, `shell/fastfetch/config.jsonc` | Declarative imported prompt/config; no shell plugin manager is declared in the active Fish modules |
| Theme/fonts | `theme.nix`, `fonts.nix`, `themes/` | Sweet-Dark GTK, BeautyLine, Sweet cursor, Nerd fonts; application-specific theming can differ |
| Qt/Kvantum | `qt-appearance.nix`, `themes/garuda-exact-kvantum/Sweet/` | Qt5ct/Qt6ct, Sweet Kvantum assets, compositing disabled; requires appearance/theme flags |
| Login greeter | `hosts/nixos/sddm-astronaut.nix`, root host config | Astronaut `black_hole` package; root `mkForce` selects `sddm-astronaut-theme`; older Elegant files remain imported |
| Night light | `hyprland/hyprsunset.nix` | HM service, 4000K at 07:30 and 3000K at 19:00, controlled by sessionAppearance |
| Lock and idle | `hyprland/{hyprlock,hypridle}.nix` and raw configs | Lua starts idle daemon, NixOS sets lock PAM; idle config also uses brightnessctl/lock-session |
| Notifications/launcher | `hyprland/{mako,wofi,drawer}.nix` | HM writes files; Lua and application flags determine startup/bindings |
| Wallpaper/dock | `hyprland/wpaperd/config.toml`, `dock/style.css` | User wallpaper folder is external personal data and must exist separately |

After editing, stage new source files and rebuild. `hyprctl reload` can reload the
compositor config after activation; check `hyprctl configerrors`. Close/restart
Waybar after configuration changes without launching a second copy alongside the
existing bar. A new Fish instance sees new shell settings. Qt session environment
changes usually need logout/login. Theme changes do not require a kernel reboot.

The original Waybar targets `wlo1` and has a fixed width inherited from its visual
design. Do not copy those values to another computer unchecked. The new portable
Hyprland profile uses a small session of its own: Super+Enter terminal, Super+D
launcher, Super+Q close, Super+1..0 workspaces; it does not activate the laptop's
Waybar, icons, wallpaper directory or application collection.

HM refuses to replace conflicting unmanaged home files rather than silently
adopting arbitrary personal state. Back up and review a conflicting file, then
move it aside deliberately. Do not delete all of `~/.config` to fix one collision.
Changing application flags removes managed files/packages, but existing app data
and external wallpaper/GPG/SSH material stay outside Git and need separate backups.
