#!/bin/bash

# auto-install.sh - Full Auto Arch Linux Installer (Entry Point)
# Description: Orchestrates the entire installation process without manual interaction.

set -e
LOG_FILE="/var/log/arch-auto-install.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# --- 1. Environment Validation ---
log "Starting Full Auto Installation..."

if [ ! -d "/sys/firmware/efi/efivars" ]; then
    error "UEFI mode NOT detected. This installer requires UEFI."
fi

if ! ping -c 1 archlinux.org &> /dev/null; then
    error "Internet connection not available."
fi

# --- 2. Partition Detection ---
log "Detecting partitions..."
# Find ARCH_ROOT
ROOT_PART=$(lsblk -nr -o NAME,LABEL,PATH | awk '$2=="ARCH_ROOT" {print $3; exit}')
if [ -z "$ROOT_PART" ]; then
    error "Partition with label 'ARCH_ROOT' not found."
fi

# Find EFI Partition
EFI_PART=$(lsblk -nr -o NAME,FSTYPE,PATH | awk '$2=="vfat" {print $3; exit}')
if [ -z "$EFI_PART" ]; then
    error "EFI partition (vfat) not found."
fi

log "Target Root: $ROOT_PART"
log "Target EFI: $EFI_PART"

# --- 3. Filesystem Setup ---
FS_TYPE=$(blkid -o value -s TYPE "$ROOT_PART")
if [ "$FS_TYPE" != "ext4" ]; then
    log "Formatting $ROOT_PART as ext4..."
    mkfs.ext4 -F -L "ARCH_ROOT" "$ROOT_PART"
else
    log "ARCH_ROOT already ext4. Skipping format."
fi

# --- 4. Mounting ---
log "Mounting partitions..."
if ! mountpoint -q /mnt; then
    mount "$ROOT_PART" /mnt
fi

mkdir -p /mnt/boot/efi
if ! mountpoint -q /mnt/boot/efi; then
    mount "$EFI_PART" /mnt/boot/efi
fi

# --- 5. Sync Script Files ---
log "Syncing internal scripts..."
mkdir -p /mnt/root/scripts
cp -r scripts/* /mnt/root/scripts/
chmod +x /mnt/root/scripts/*.sh

# --- 6. Execution Chain ---
log "Starting System Installation (Step 1/3)..."
arch-chroot /mnt /root/scripts/system-install.sh

log "Starting Bootloader Installation (Step 2/3)..."
arch-chroot /mnt /root/scripts/bootloader-install.sh

log "Starting Validation Check (Step 3/3)..."
arch-chroot /mnt /root/scripts/validation-check.sh

log "FULL AUTO INSTALLATION COMPLETED SUCCESSFULLY!"
log "Log file available at: $LOG_FILE"
echo -e "${GREEN}You can now safely reboot.${NC}"
