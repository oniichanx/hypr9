#!/usr/bin/env bash
# /* ---- 💫 https://github.com/oniichanx 💫 ---- */  ##

ws=$(hyprctl activeworkspace -j | jq -r .id)
hyprctl clients -j | jq -r --arg ws "$ws" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | xargs -r -I {} hyprctl dispatch togglefloating address:{}