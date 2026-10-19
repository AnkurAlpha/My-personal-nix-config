#!/bin/sh
# "Change keyboard layout in" "~/.config/hypr/hyprland.lua" " " \

yad --width=640 --height=700 \
--center \
--fixed \
--title="Garuda Hyprland Keybindings" \
--no-buttons \
--list \
--column=Key: \
--column=Description: \
--column=Command: \
--timeout=60 \
--timeout-indicator=right \
"ESC" "close this app" "" "=" "modkey" "(set mod Mod4)" \
"+s" "G-hyprland" "A setting script" \
"+enter/+t" "Terminal" "(foot)" \
"" "Application Menu" "(wofi)" \
"+Shift+d" "Full Launcher" "(nwggrid)" \
"+o" "" "Open Broswer" \
"+e" "💧" "Emoje selector" \
"+n" "" "Open Files" \
"+q" "close focused app" "(kill)" \
"+v" "clipboard manager" "(cliphist)" \
"+r" "Resize windows" "(resize)" \
"Print" "screenshot" "(grimblast)" \
"Shift+Print" "screenshot region" "(grimblast)" \
"+Print" "screenshot window" "(grimblast)" \
"+Shift+e" "power-menu" "(wofi)" \
"+Shift+c" "Change wallpaper" "(wpaperd)" \
"+Shift+b" "Increase brightness" "brightnessctl" \
"+b" "Decrease brightness" "brightnessctl" \
"+f" "Fullscreen" "Toggles to full screen" \
"+Shift+f" "fullscreenstate" "Behave full screen without full screen" \
"+m" "maximize" "Hides all the windows other then focused window" \
"+Shift+Spacebar" "Float" "Toggle windows to float" \
"+p" "Dwindle effect" "pseudo" \
"+Shift+p" "Dwindle effect" "toggle split" \
"+Shift+g" "G-hyprland" "add/remove G-Hyprland" \
"+i" "Calamares" "Install Garuda Hyprland" \
"Window will be closed in 60 sec" "" ""\
