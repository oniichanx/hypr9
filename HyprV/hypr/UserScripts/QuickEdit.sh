#!/bin/bash
# /* ---- 💫 https://github.com/oniichanx 💫 ---- */  ##
# Rofi menu for Quick Edit/View of Settings (SUPER E)

# Define preferred text editor and terminal
edit=${EDITOR:-nano}
tty=kitty

# Paths to configuration directories
configs="$HOME/.config/hypr/configs"
UserConfigs="$HOME/.config/hypr/UserConfigs"
UserSettings="$HOME/.config/hypr"
scriptsDir="$HOME/.config/hypr/scripts"

# Function to display the menu options
menu() {
    cat <<EOF
1. View / Edit  Default-Settings
2. View / Edit  Default-Apps
3. View / Edit  User-Settings
4. View / Edit  Default-Keybinds
5. View / Edit  Decorations & Animations
6. View / Edit  Workspace-Rules
7. View / Edit  Workspace-Rules-new
8. View / Edit  Change SDDM Wallpaper
9. View / Edit  Choose Kitty Terminal Theme

EOF
}

# Main function to handle menu selection
main() {
    choice=$(menu | rofi -i -dmenu -config ~/.config/rofi/config-edit.rasi | cut -d. -f1)
    
    # Map choices to corresponding files
    case $choice in
        1) file="$UserConfigs/Settings.conf" ;;
        2) file="$UserConfigs/Default-Apps.conf" ;;
        3) file="$UserSettings/hyprland.conf" ;;
        4) file="$UserConfigs/KeyBinds.conf" ;;
        5) file="$UserConfigs/UserDecorAnimations.conf" ;;
        6) file="$UserConfigs/WindowRules.conf" ;;
        7) file="$UserConfigs/WindowRules-new.conf" ;;
        8) $scriptsDir/sddm_wallpaper.sh ;;
        9) $scriptsDir/Kitty_themes.sh ;;
        *) return ;;  # Do nothing for invalid choices
    esac

    # Open the selected file in the terminal with the text editor
    if [ -n "$file" ]; then
        $tty -e $edit "$file"
    fi
}

# Check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

main
