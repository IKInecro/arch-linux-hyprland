#!/bin/bash

# install-grub.sh - Arch Linux Bootloader Installer
# Description: Idempotent GRUB setup with Matrix theme (Modular Step 2)
# Tasks: Install GRUB, efibootmgr, os-prober, Matrix Theme, Config OS-Prober.

set -e
LOG_FILE="/var/log/arch-hyprland-install.log"
ROOT_LABEL="ARCH_ROOT"
THEME_URL="https://github.com/Priyank-Adhav/Matrix-Morpheus-GRUB-Theme"
THEME_DIR="/boot/grub/themes/Matrix-Morpheus"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# --- Initial Checks ---
log "Starting Step 2: Bootloader Installation..."

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root."
fi

# Detect partitions again for standalone run
ROOT_PART=$(lsblk -nr -o NAME,LABEL,PATH | awk '$2=="ARCH_ROOT" {print $3; exit}')
EFI_PART=$(lsblk -nr -o NAME,FSTYPE,PATH | awk '$2=="vfat" {print $3; exit}')

if [ -z "$ROOT_PART" ] || [ -z "$EFI_PART" ]; then
    error "Could not detect ARCH_ROOT or EFI partition. Step 1 probably failed."
fi

# --- Mounting (Safety) ---
if ! mountpoint -q /mnt; then
    mount "$ROOT_PART" /mnt
fi

mkdir -p /mnt/boot/efi
if ! mountpoint -q /mnt/boot/efi; then
    mount "$EFI_PART" /mnt/boot/efi
fi

# --- Chroot execution ---
log "Configuring GRUB inside chroot..."
arch-chroot /mnt bash <<EOF
set -e
LOG_FILE="/var/log/arch-hyprland-install.log"
log() { echo -e "\033[0;32m[\$(date +'%H:%M:%S')] \$1\033[0m" | tee -a "\$LOG_FILE"; }

# Install packages
PACKAGES=(grub efibootmgr os-prober git)
for pkg in "\${PACKAGES[@]}"; do
    if ! pacman -Qi "\$pkg" &>/dev/null; then
        log "Installing \$pkg..."
        pacman -S --noconfirm "\$pkg"
    fi
done

# GRUB Install
log "Running grub-install..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck

# OS-Prober Configuration
log "Enabling os-prober for Dual Boot..."
if grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
    sed -i 's/.*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

# Theme Installation
log "Installing Matrix Theme..."
mkdir -p /boot/grub/themes
if [ ! -d "$THEME_DIR" ]; then
    git clone "$THEME_URL" "$THEME_DIR"
fi

# Set Theme in /etc/default/grub
if grep -q "GRUB_THEME=" /etc/default/grub; then
    sed -i 's|.*GRUB_THEME=.*|GRUB_THEME="$THEME_DIR/theme.txt"|' /etc/default/grub
else
    echo 'GRUB_THEME="$THEME_DIR/theme.txt"' >> /etc/default/grub
fi

# Generate Config
log "Generating grub.cfg..."
grub-mkconfig -o /boot/grub/grub.cfg

log "Bootloader Step Completed!"
EOF

log "Step 2 Finished Successfully!"
echo "Reboot now to enter your new Arch Hyprland system."
