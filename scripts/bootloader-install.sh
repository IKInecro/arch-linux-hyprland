#!/bin/bash

# scripts/bootloader-install.sh - Bootloader & Dual-Boot Setup
# Description: Installs GRUB, configures os-prober, and applies Matrix theme.

set -e
LOG_FILE="/var/log/arch-auto-install.log"
THEME_URL="https://github.com/Priyank-Adhav/Matrix-Morpheus-GRUB-Theme"
THEME_DIR="/boot/grub/themes/Matrix-Morpheus"

log() {
    echo -e "\033[0;32m[$(date +'%H:%M:%S')] $1\033[0m" | tee -a "$LOG_FILE"
}

error() {
    echo -e "\033[0;31m[$(date +'%H:%M:%S')] ERROR: $1\033[0m" | tee -a "$LOG_FILE"
    exit 1
}

# --- Validation ---
if ! mountpoint -q /boot/efi; then
    error "/boot/efi is not mounted. Bootloader setup cannot continue."
fi

# --- Package installation ---
PKGS=(grub efibootmgr os-prober git)
for pkg in "${PKGS[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        pacman -S --noconfirm "$pkg"
    fi
done

# --- GRUB Install (Self-Healing / Removable) ---
log "Installing GRUB to EFI partition..."
# Using --recheck and --removable to ensure the motherboard identifies it correctly.
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable

# Verify file exists
if [ ! -f "/boot/efi/EFI/BOOT/BOOTX64.EFI" ]; then
    error "GRUB Installation failed. Removable binary not found."
fi

# --- Dual Boot / os-prober ---
log "Configuring Dual-Boot support..."
if grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
    sed -i 's/.*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
else
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
fi

# --- Theme Setup ---
log "Installing Matrix Theme..."
mkdir -p /boot/grub/themes
if [ ! -d "$THEME_DIR" ]; then
    git clone "$THEME_URL" "$THEME_DIR"
fi

if grep -q "GRUB_THEME=" /etc/default/grub; then
    sed -i 's|.*GRUB_THEME=.*|GRUB_THEME="'$THEME_DIR'/theme.txt"|' /etc/default/grub
else
    echo 'GRUB_THEME="'$THEME_DIR'/theme.txt"' >> /etc/default/grub
fi

# --- Final Config ---
log "Generating grub.cfg..."
grub-mkconfig -o /boot/grub/grub.cfg

log "Bootloader configuration finished."
exit 0
