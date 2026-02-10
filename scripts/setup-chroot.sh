#!/bin/bash

# scripts/setup-chroot.sh - Arch Linux Configuration (Step 1.1)
# Tasks: Timezone, Locale, Hostname, User, Desktop Packages, Services.

set -e
LOG_FILE="/var/log/arch-hyprland-install.log"

log() {
    echo -e "\033[0;32m[$(date +'%H:%M:%S')] $1\033[0m" | tee -a "$LOG_FILE"
}

# --- Core Config ---
log "Configuring Timezone & Locale..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

if ! grep -q "en_US.UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
fi
echo "LANG=en_US.UTF-8" > /etc/locale.conf

log "Setting Hostname..."
echo "arch-hypr" > /etc/hostname
if ! grep -q "arch-hypr" /etc/hosts; then
    {
        echo "127.0.0.1   localhost"
        echo "::1         localhost"
        echo "127.0.1.1   arch-hypr.localdomain arch-hypr"
    } >> /etc/hosts
fi

# --- User & Sudo ---
USERNAME="JAWA"
PASSWORD="123"

if ! id "$USERNAME" &>/dev/null; then
    log "Creating user $USERNAME..."
    useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "root:$PASSWORD" | chpasswd
fi

mkdir -p /etc/sudoers.d
if [ ! -f /etc/sudoers.d/wheel ]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
fi

# --- Desktop Packages ---
log "Installing Desktop Stack..."
DESKTOP_PKGS=(
    hyprland waybar kitty rofi-wayland dolphin sddm
    pipewire pipewire-pulse wireplumber wl-clipboard
    grim slurp fastfetch xdg-desktop-portal-hyprland
    neovim curl wget firefox ttf-font-awesome noto-fonts-emoji
)

# Idempotent package install
for pkg in "${DESKTOP_PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        log "Installing $pkg..."
        pacman -S --noconfirm "$pkg"
    fi
done

# --- Services ---
log "Enabling Services..."
systemctl enable NetworkManager || true
systemctl enable sddm || true

log "Chroot Configuration Finished!"
exit 0
