#!/bin/bash
set -euo pipefail

# ================== Colors ==================
if command -v tput &>/dev/null && tput setaf 1 &>/dev/null; then
    OK="$(tput setaf 2)[OK]$(tput sgr0)"
    ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
    NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
    INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
    WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
else
    OK="[OK]" ; ERROR="[ERROR]" ; NOTE="[NOTE]" ; INFO="[INFO]" ; WARN="[WARN]"
fi

mkdir -p Install-Logs
LOG="Install-Logs/install-$(date +%d-%H%M%S).log"

echo -e "${NOTE} HyprV4 Ultra-Fast Installation Script (2026)" | tee -a "$LOG"

# ================== Root Check ==================
if [[ "$EUID" -eq 0 ]]; then
    echo -e "${ERROR} Do not run as root!" && exit 1
fi
sudo -v || { echo -e "${ERROR} Sudo required."; exit 1; }

trap 'echo -e "\n${ERROR} Interrupted! Check $LOG"; exit 1' INT TERM ERR

# ================== Base deps ==================
echo -e "${NOTE} Installing base dependencies..." | tee -a "$LOG"
sudo pacman -Syu --noconfirm --needed base-devel git pciutils >> "$LOG" 2>&1

# ================== Choose AUR Helper (Fast binary version) ==================
echo -e "${NOTE} Choose AUR Helper:"
echo "1) paru (recommended - fast)"
echo "2) yay"
read -rep $'[\e[1;33mACTION\e[0m] Enter 1 or 2: ' AURCHOICE

if [[ $AURCHOICE == "1" ]]; then
    AURHELPER="paru"
    AURBIN="paru-bin"
else
    AURHELPER="yay"
    AURBIN="yay-bin"
fi

if ! command -v "$AURHELPER" &>/dev/null; then
    echo -e "${NOTE} Installing $AURHELPER-bin (fast)..." | tee -a "$LOG"
    git clone https://aur.archlinux.org/"$AURBIN".git --depth=1
    cd "$AURBIN" && makepkg -si --noconfirm && cd .. && rm -rf "$AURBIN"
fi

# Speed up makepkg (no compression + full cores)
echo -e "${NOTE} Optimizing makepkg for speed..." | tee -a "$LOG"
sudo sed -i 's/^PKGEXT=.*/PKGEXT='\''.pkg.tar'\''/' /etc/makepkg.conf 2>/dev/null || true
sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf 2>/dev/null || true

# ================== Hyprland choice ==================
echo -e "${NOTE} Select Hyprland:"
echo "1) hyprland-git (bleeding-edge)"
echo "2) hyprland (stable)"
read -rep $'[\e[1;33mACTION\e[0m] Enter 1 or 2: ' HYPRCHOICE

if [[ $HYPRCHOICE == "1" ]]; then
    HYPR_PACKAGE="hyprland-git"
    PORTAL_PACKAGE="xdg-desktop-portal-hyprland-git"
else
    HYPR_PACKAGE="hyprland"
    PORTAL_PACKAGE="xdg-desktop-portal-hyprland"
fi

read -rep $'[\e[1;33mACTION\e[0m] Continue with ultra-fast install? (y/n): ' CONT
[[ $CONT =~ ^[Yy]$ ]] || { echo -e "${NOTE} Cancelled."; exit 0; }

# ================== Detection ==================
ISNVIDIA=false
[[ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia) ]] && ISNVIDIA=true && echo -e "${NOTE} NVIDIA detected."

# VM Warning
if command -v systemd-detect-virt &>/dev/null; then
    VIRT=$(systemd-detect-virt 2>/dev/null || echo none)
    if [[ "$VIRT" != "none" ]]; then
        echo -e "${WARN} VM detected ($VIRT). May fail." | tee -a "$LOG"
        read -rep $'[\e[1;33mACTION\e[0m] Continue anyway? (y/n): ' VMOK
        [[ $VMOK =~ ^[Yy]$ ]] || exit 0
    fi
fi

# ================== Package Lists ==================
prep_stage=(qt5-wayland qt5ct qt6-wayland qt6ct qt5-svg qt5-quickcontrols2 qt5-graphicaleffects gtk3 polkit polkit-gnome pipewire wireplumber jq wl-clipboard cliphist python-requests python-pyquery pacman-contrib)

nvidia_stage=(linux-zen linux-zen-headers nvidia-open-dkms nvidia-settings libva libva-nvidia-driver-git)

install_stage=(kitty swaync waybar swww hyprlock wallust yad bc rofi-wayland imagemagick bibata-cursor-theme-bin wlogout swappy grim slurp thunar btop firefox librewolf-bin thunderbird mpv pamixer pavucontrol brightnessctl bluez bluez-utils blueman network-manager-applet gvfs thunar-archive-plugin file-roller starship papirus-icon-theme ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-droid ttf-fira-code noto-fonts-emoji adobe-source-code-pro-fonts otf-font-awesome lxappearance xfce4-settings nwg-look sddm hyprpolkitagent xdg-utils)

# ================== Fast Batch Install ==================
read -rep $'[\e[1;33mACTION\e[0m] Install all packages now? (y/n): ' INST
if [[ $INST =~ ^[Yy]$ ]]; then
    echo -e "${NOTE} Starting ultra-fast batch installation..." | tee -a "$LOG"

    ALL_PKGS=("${prep_stage[@]}")
    [[ "$ISNVIDIA" == true ]] && ALL_PKGS+=("${nvidia_stage[@]}")
    ALL_PKGS+=("$HYPR_PACKAGE" "$PORTAL_PACKAGE" "${install_stage[@]}")

    # Install from official repos first (very fast)
    echo -e "${NOTE} Installing official packages..." | tee -a "$LOG"
    sudo pacman -S --noconfirm --needed "${ALL_PKGS[@]}" 2>&1 | tee -a "$LOG" || true

    # AUR packages (with speed flags)
    echo -e "${NOTE} Installing AUR packages with speed options..." | tee -a "$LOG"
    if [[ "$AURHELPER" == "paru" ]]; then
        paru -S --noconfirm --skipreview --bottomup --needed bibata-cursor-theme-bin librewolf-bin 2>&1 | tee -a "$LOG"
    else
        yay -S --noconfirm --needed bibata-cursor-theme-bin librewolf-bin 2>&1 | tee -a "$LOG"
    fi

    # NVIDIA setup
    if [[ "$ISNVIDIA" == true ]]; then
        echo -e "${NOTE} Configuring NVIDIA..." | tee -a "$LOG"
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf 2>/dev/null || true
        sudo mkinitcpio -P >> "$LOG" 2>&1

        echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

        if [[ -f /boot/grub/grub.cfg ]]; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg >> "$LOG" 2>&1
        elif [[ -d /boot/loader/entries ]]; then
            for entry in /boot/loader/entries/*.conf; do
                sudo sed -i 's/^options /options nvidia_drm.modeset=1 /' "$entry" 2>/dev/null || true
            done
        fi
    fi

    sudo pacman -R --noconfirm xdg-desktop-portal-gnome xdg-desktop-portal-gtk 2>/dev/null || true
    sudo systemctl enable --now bluetooth sddm
fi

# ================== Config Copy (เหมือนเดิม) ==================
read -rep $'[\e[1;33mACTION\e[0m] Copy config files? (y/n): ' CFG
if [[ $CFG =~ ^[Yy]$ ]]; then
    if [[ ! -d "HyprV" ]]; then
        echo -e "${ERROR} HyprV folder not found in current directory!" && exit 1
    fi

    echo -e "${NOTE} Copying & linking configs..." | tee -a "$LOG"
    cp -R HyprV ~/.config/

    # Backup & link (ย่อลงแต่ครบ)
    for dir in hypr kitty swaync swaylock waybar wlogout rofi; do
        [[ -d ~/.config/$dir ]] && mv ~/.config/$dir ~/.config/"$dir"-backup 2>/dev/null || true
        mkdir -p ~/.config/$dir
    done

    # [hyprland] cp (ไม่ใช่ ln) เพราะ hyprland.conf ถูก append nvidia/rog ทีหลัง
    cp -r ~/.config/HyprV/hypr/* ~/.config/hypr/ 2>/dev/null || true

    # [rofi] cp — config.rasi + themes/ + launcher scripts
    cp -r ~/.config/HyprV/rofi/* ~/.config/rofi/ 2>/dev/null || true

    # [wallpaper] cp ไปไว้ ~/Pictures/ ให้ swww ใช้ตอน startup
    cp -r ~/.config/HyprV/Pictures ~/ 2>/dev/null || true

    # [kitty] ln: kitty.conf (live-update) / cp: themes (static)
    ln -sf ~/.config/HyprV/kitty/kitty.conf ~/.config/kitty/kitty.conf 2>/dev/null || true
    cp -r ~/.config/HyprV/kitty/kitty-themes/ ~/.config/kitty/kitty-themes 2>/dev/null || true

    # [swaync] ln: config.json, style.css, icons/, images/ — restart: swaync -R && swaync
    ln -sf ~/.config/HyprV/swaync/config.json ~/.config/swaync/config.json 2>/dev/null || true
    ln -sf ~/.config/HyprV/swaync/style.css ~/.config/swaync/style.css 2>/dev/null || true
    ln -sf ~/.config/HyprV/swaync/icons ~/.config/swaync 2>/dev/null || true
    ln -sf ~/.config/HyprV/swaync/images ~/.config/swaync 2>/dev/null || true

    # [waybar] layout + theme default — เปลี่ยนแค่ชี้ symlink ใหม่ไปที่ configs/ หรือ style/
    ln -sf ~/.config/HyprV/waybar/configs/[TOP]\ Simple ~/.config/waybar/config 2>/dev/null || true
    ln -sf ~/.config/HyprV/waybar/style/[Colored]\ Translucent.css ~/.config/waybar/style.css 2>/dev/null || true

    # [wlogout] ln: layout, icons/, style.css — check: ls -la ~/.config/wlogout/
    ln -sf ~/.config/HyprV/wlogout/layout ~/.config/wlogout/layout 2>/dev/null || true
    ln -sf ~/.config/HyprV/wlogout/icons ~/.config/wlogout/icons 2>/dev/null || true
    ln -sf ~/.config/HyprV/wlogout/style.css ~/.config/wlogout/style.css 2>/dev/null || true

    # [waybar modules] ln: Modules, Custom, Groups, Workspaces, Vertical — reload: killall waybar && waybar &
    ln -sf ~/.config/HyprV/waybar/Modules ~/.config/waybar/Modules 2>/dev/null || true
    ln -sf ~/.config/HyprV/waybar/ModulesCustom ~/.config/waybar/ModulesCustom 2>/dev/null || true
    ln -sf ~/.config/HyprV/waybar/ModulesGroups ~/.config/waybar/ModulesGroups 2>/dev/null || true
    ln -sf ~/.config/HyprV/waybar/ModulesWorkspaces ~/.config/waybar/ModulesWorkspaces 2>/dev/null || true
    ln -sf ~/.config/HyprV/waybar/ModulesVertical ~/.config/waybar/ModulesVertical 2>/dev/null || true

    # [wallust] ln: waybar/wallust (color template) + ~/.config/wallust (config หลัก) — fix: wallust run ~/Pictures/<img>
    ln -sf ~/.config/HyprV/waybar/wallust ~/.config/waybar/wallust 2>/dev/null || true
    ln -sf ~/.config/HyprV/wallust ~/.config/wallust 2>/dev/null || true

    # [waybar style folder] ln: style/ ทั้งโฟลเดอร์ — ต้องมีก่อนเพราะ style.css ชี้ไฟล์ข้างใน
    ln -sf ~/.config/HyprV/waybar/style ~/.config/waybar/style 2>/dev/null || true

    if [[ "$ISNVIDIA" == true ]]; then
        grep -q "env_var_nvidia.conf" ~/.config/hypr/hyprland.conf || echo -e "\nsource = ~/.config/hypr/env_var_nvidia.conf" >> ~/.config/hypr/hyprland.conf
    fi

    # SDDM Theme
    sudo cp -R Extras/sdt /usr/share/sddm/themes/ 2>/dev/null || true
    echo -e "[Theme]\nCurrent=sdt" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
    sudo cp Extras/hyprland.desktop /usr/share/wayland-sessions/ 2>/dev/null || true

    echo -e "${OK} Configs done."
fi

# ================== Final quick steps ==================
read -rep $'[\e[1;33mACTION\e[0m] Enable Starship? (y/n): ' STAR
[[ $STAR =~ ^[Yy]$ ]] && echo 'eval "$(starship init bash)"' >> ~/.bashrc && cp Extras/starship.toml ~/.config/ 2>/dev/null || true

read -rep $'[\e[1;33mACTION\e[0m] Enable wallpaper on startup? (y/n): ' WALL
[[ $WALL =~ ^[Yy]$ ]] && sed -i 's|#exec-once = ~/.config/hypr/startup.sh|exec-once = ~/.config/hypr/startup.sh|' ~/.config/hypr/hyprland.conf 2>/dev/null || true

echo -e "${OK} Installation completed successfully!"
echo -e "${NOTE} Reboot recommended."

read -rep $'[\e[1;33mACTION\e[0m] Reboot now? (y/n): ' REBOOT
[[ $REBOOT =~ ^[Yy]$ ]] && sudo reboot