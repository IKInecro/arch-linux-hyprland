#!/bin/bash

# install-arch.sh - Arch Linux Base System Installer
# Description: Idempotent base installer (Modular Step 1)
# Tasks: Detect partitions, mount, pacstrap base, setup basic config.

set -e # Exit on error
LOG_FILE="/var/log/arch-hyprland-install.log"
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

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

# --- Initial Checks ---
log "Starting Step 1: Base System Installation..."

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root."
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
    error "UEFI mode NOT detected. Arch Linux requires UEFI for this setup."
fi

# --- Partition Detection ---
log "Detecting partitions..."
ROOT_PART=$(lsblk -nr -o NAME,LABEL,PATH | awk '$2=="ARCH_ROOT" {print $3; exit}')

if [ -z "$ROOT_PART" ]; then
    error "Could not find partition with label 'ARCH_ROOT'. Please label your partition first."
fi

# Detect EFI partition (FileSystem vfat)
EFI_PART=$(lsblk -nr -o NAME,FSTYPE,PATH | awk '$2=="vfat" {print $3; exit}')

if [ -z "$EFI_PART" ]; then
    error "EFI partition (vfat) not found."
fi

log "Root Partition: $ROOT_PART"
log "EFI Partition: $EFI_PART"

# --- Mounting ---
log "Mounting system partitions..."
if ! mountpoint -q /mnt; then
    mount "$ROOT_PART" /mnt
fi

mkdir -p /mnt/boot/efi
if ! mountpoint -q /mnt/boot/efi; then
    mount "$EFI_PART" /mnt/boot/efi
fi

# --- Base Installation ---
log "Installing foundational packages..."
# base, linux, linux-firmware are mandatory
# sudo, networkmanager, base-devel, git are needed for Step 2
BASE_PACKAGES=(base linux linux-firmware sudo networkmanager base-devel git)

if [ ! -f "/mnt/bin/bash" ]; then
    pacstrap -K /mnt "${BASE_PACKAGES[@]}"
else
    log "Base system already detected. Skipping pacstrap."
fi

# --- Fstab Generation ---
if [ ! -f "/mnt/etc/fstab" ] || [ ! -s "/mnt/etc/fstab" ]; then
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
fi

# --- Sync Scripts ---
log "Syncing configuration scripts..."
mkdir -p /mnt/root/scripts
cp scripts/setup-chroot.sh /mnt/root/scripts/
chmod +x /mnt/root/scripts/setup-chroot.sh

# --- Run Chroot Setup ---
log "Entering chroot to configure system..."
arch-chroot /mnt /root/scripts/setup-chroot.sh

log "Step 1 (Base Installation) Completed!"
log "Next step: Run ./install-grub.sh to setup bootloader."
