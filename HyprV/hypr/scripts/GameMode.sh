#!/bin/bash
# /* ---- 💫 https://github.com/oniichanx 💫 ---- */  ##
# Game Mode. Turning off all animations

notif="$HOME/.config/HyprV/swaync/images/ja.png"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$HYPRGAMEMODE" = 1 ]; then
    # Enable gamemode and send notification
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    swww kill 
    notify-send -e -u low -i "$notif" " Gamemode" " Enabled"
    exit
else
    # Restore normal mode and send notification
    hyprctl --batch "\
        keyword animations:enabled 1;\
        keyword decoration:shadow:enabled 1;\
        keyword decoration:blur:enabled 1;\
        keyword general:gaps_in 5;\
        keyword general:gaps_out 10;\
        keyword general:border_size 2;\
        keyword decoration:rounding 5"
    swww-daemon --format xrgb && swww img "$HOME/.config/rofi/.current_wallpaper" &
    sleep 0.1
    ${SCRIPTSDIR}/WallustSwww.sh
    sleep 0.5
    ${SCRIPTSDIR}/Refresh.sh
    notify-send -e -u normal -i "$notif" " Gamemode" " Disabled"
    exit
fi

hyprctl reload
