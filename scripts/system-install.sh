#!/bin/bash

# scripts/system-install.sh - System & Desktop Installation
# Description: Installs base packages, configures system, user, and desktop.

set -e
LOG_FILE="/var/log/arch-auto-install.log"

log() {
    echo -e "\033[0;32m[$(date +'%H:%M:%S')] $1\033[0m" | tee -a "$LOG_FILE"
}

# --- Base Installation ---
log "Running pacstrap foundation..."
PKGS=(base linux linux-firmware sudo networkmanager base-devel git hyprland waybar kitty rofi-wayland sddm pipewire wireplumber firefox ttf-font-awesome noto-fonts-emoji)

# Check if pacstrap is already done by looking for bash in /mnt (which is / inside chroot)
if [ ! -f "/bin/bash" ]; then
    # Since we are INSIDE chroot, we use pacman for package idempotency
    pacman -Syu --noconfirm "${PKGS[@]}"
else
    log "System foundation detected. Checking for missing packages..."
    for pkg in "${PKGS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            pacman -S --noconfirm "$pkg"
        fi
    done
fi

# --- Configuration ---
log "Configuring Timezone, Locale, Hostname..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

if ! grep -q "en_US.UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
fi
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "arch-hypr" > /etc/hostname

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
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# --- Services ---
log "Enabling SDDM and NetworkManager..."
systemctl enable NetworkManager || true
systemctl enable sddm || true

# --- Dotfiles ---
DOT_DIR="/home/$USERNAME/shell"
if [ ! -d "$DOT_DIR" ]; then
    log "Cloning Caelestia dotfiles..."
    su - "$USERNAME" -c "git clone https://github.com/caelestia-dots/shell $DOT_DIR"
fi

log "System Installation Finish."
exit 0
