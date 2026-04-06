#!/usr/bin/env bash
SCRIPTSDIR="$HOME/.config/hypr/scripts"
. "$SCRIPTSDIR/WallpaperCmd.sh"

# เช็คก่อนว่า daemon รันอยู่หรือเปล่า
if ! pgrep -x "$WWW_DAEMON" >/dev/null 2>&1; then
  "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}" &
fi