#!/bin/bash
# 💫 https://github.com/oniichanx 💫

layout_file="$HOME/.cache/kb_layout"
settings_file="$HOME/.config/hypr/UserConfigs/Settings.conf"
notif_icon="$HOME/.config/HyprV/swaync/icons/ja.png"

ignore_patterns=(
  "--(avrcp)"
  "Bluetooth Speaker"
  "Other Device Name"
)

# 🛠️ Create layout file if not exists
if [ ! -f "$layout_file" ]; then
  echo "Creating layout file..."
  default_layout=$(grep 'kb_layout = ' "$settings_file" | cut -d '=' -f 2 | tr -d '[:space:]' | cut -d ',' -f 1 2>/dev/null)
  default_layout=${default_layout:-"us"}
  echo "$default_layout" > "$layout_file"
  echo "Default layout set to $default_layout"
fi

current_layout=$(cat "$layout_file")
echo "Current layout: $current_layout"

# 🗂️ Read available layouts
if [ -f "$settings_file" ]; then
  kb_layout_line=$(grep 'kb_layout = ' "$settings_file" | cut -d '=' -f 2)
  kb_layout_line=$(echo "$kb_layout_line" | tr -d '[:space:]')
  IFS=',' read -r -a layout_mapping <<< "$kb_layout_line"
else
  echo "Settings file not found!"
  exit 1
fi

layout_count=${#layout_mapping[@]}
echo "Number of layouts: $layout_count"

# 🔁 Cycle to next layout
for ((i = 0; i < layout_count; i++)); do
  if [ "$current_layout" == "${layout_mapping[i]}" ]; then
    current_index=$i
    break
  fi
done

next_index=$(( (current_index + 1) % layout_count ))
new_layout="${layout_mapping[next_index]}"
echo "Next layout: $new_layout"

# 📘 Mapping layout code → display name
get_layout_name() {
  case "$1" in
    us) echo "English 🇺🇸" ;;
    th) echo "ไทย 🇹🇭" ;;
    de) echo "Deutsch 🇩🇪" ;;
    fr) echo "Français 🇫🇷" ;;
    jp) echo "日本語 🇯🇵" ;;
    *) echo "$1" ;; # fallback
  esac
}

# 🧠 Device name filters
get_keyboard_names() {
  hyprctl devices -j | jq -r '.keyboards[].name'
}

is_ignored() {
  local device_name=$1
  for pattern in "${ignore_patterns[@]}"; do
    if [[ "$device_name" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# 🔄 Change layout (fixed to match kb_layout order)
change_layout() {
  local error_found=false
  local target_index=$next_index

  while read -r name; do
    if is_ignored "$name"; then
      echo "Skipping ignored device: $name"
      continue
    fi

    echo "Setting layout for $name to index $target_index (${layout_mapping[target_index]})"
    hyprctl switchxkblayout "$name" "$target_index"
    if [ $? -ne 0 ]; then
      echo "Error while switching layout for $name." >&2
      error_found=true
    fi
  done <<< "$(get_keyboard_names)"

  $error_found && return 1
  return 0
}

# 🔔 Show notification and update file
if ! change_layout; then
  #notify-send -u low -t 2000 "⌨️ Layout Change Error" "Layout switch failed"
  echo "Layout change failed." >&2
  exit 1
else
  layout_display_name=$(get_layout_name "$new_layout")
  #notify-send -u low -i "$notif_icon" "$layout_display_name"
  echo "Layout changed to: $layout_display_name"
fi

echo "$new_layout" > "$layout_file"
