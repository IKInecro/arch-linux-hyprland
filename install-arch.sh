#!/bin/bash

# install-arch.sh - Arch Linux Hyprland Installer (Revised)
# Description: Automated, idempotent installer with dual-boot and recovery support.

set -e # Exit on error

# --- Configuration & Logging ---
LOG_FILE="/var/log/arch-hyprland-install.log"
# Ensure log directory exists if we're on a live system (it usually does)
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
log "Starting Arch Linux + Hyprland Installer Revision..."

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root."
fi

if [ ! -d "/sys/firmware/efi/efivars" ]; then
    error "UEFI mode NOT detected. Please boot in UEFI mode for dual-boot support."
fi

log "Checking internet connection..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    error "No internet connection. Please connect to the internet first."
fi

# --- Partition Detection ---
log "Detecting partitions..."

# Priority 1: Label ARCH_ROOT, Priority 2: Label fydeos
ROOT_PART=$(lsblk -o NAME,LABEL,PATH -nr | grep -E "ARCH_ROOT|fydeos" | head -n 1 | awk '{print $3}')

if [ -z "$ROOT_PART" ]; then
    error "Could not find partition with label 'ARCH_ROOT' or 'fydeos'. Please label your target partition first."
fi

# Detect EFI partition (FileSystem vfat on same disk or system-wide)
DISK=$(lsblk -no pkname "$ROOT_PART" | head -n 1)
EFI_PART=$(lsblk -o NAME,FSTYPE,PATH,PKNAME -nr | grep "$DISK" | grep "vfat" | head -n 1 | awk '{print $3}')

if [ -z "$EFI_PART" ]; then
    EFI_PART=$(lsblk -o NAME,FSTYPE,PATH -nr | grep "vfat" | head -n 1 | awk '{print $3}')
    if [ -z "$EFI_PART" ]; then
        error "EFI partition (vfat) not found. UEFI system requires a vfat EFI partition."
    fi
    warn "EFI partition found on separate disk: $EFI_PART"
fi

log "Root Partition identified: $ROOT_PART"
log "EFI Partition identified: $EFI_PART"

# --- Idempotency Logic: Formatting ---
SHOULD_FORMAT=true
FS_TYPE=$(blkid -o value -s TYPE "$ROOT_PART")

if [ "$FS_TYPE" == "ext4" ]; then
    # Check if it looks like a Linux system already
    mkdir -p /tmp/check_mnt
    mount "$ROOT_PART" /tmp/check_mnt
    if [ -d "/tmp/check_mnt/etc" ] && [ -d "/tmp/check_mnt/usr" ]; then
        log "Detected existing Linux installation on $ROOT_PART. Skipping format."
        SHOULD_FORMAT=false
    fi
    umount /tmp/check_mnt
fi

if [ "$SHOULD_FORMAT" = true ]; then
    echo -e "${YELLOW}WARNING: $ROOT_PART will be FORMATTED as ext4.${NC}"
    read -p "Proceed with formatting? (yes/NO): " confirm
    if [[ "$confirm" == "yes" ]]; then
        log "Formatting $ROOT_PART..."
        mkfs.ext4 -F -L "ARCH_ROOT" "$ROOT_PART"
    else
        error "Formatting aborted. Cannot proceed without a clean or compatible partition."
    fi
fi

# --- Mounting ---
log "Setting up mount points..."

if ! mountpoint -q /mnt; then
    mount "$ROOT_PART" /mnt
fi

# Ensure /mnt/boot/efi exists
mkdir -p /mnt/boot/efi

if ! mountpoint -q /mnt/boot/efi; then
    mount "$EFI_PART" /mnt/boot/efi
fi

# Safety Check: Verify Mount Structure
if [ ! -d "/mnt/boot/efi/EFI" ] && [ ! -d "/mnt/boot/efi/efi" ]; then
    warn "EFI partition does not seem to contain standard EFI directory. GRUB will create it."
fi

# --- Base Installation ---
log "Installing Base System..."
# Use pacman -Qq to check if base is already there (idempotency point)
if [ ! -f "/mnt/bin/bash" ]; then
    pacstrap -K /mnt base linux linux-firmware vim nano intel-ucode amd-ucode
else
    log "Base system already detected in /mnt. Skipping pacstrap."
fi

# --- Configuration ---
if [ ! -f "/mnt/etc/fstab" ] || [ ! -s "/mnt/etc/fstab" ]; then
    log "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
fi

# Sync scripts for chroot
log "Syncing scripts..."
mkdir -p /mnt/root/scripts /mnt/var/log
cp -r scripts/* /mnt/root/scripts/
chmod +x /mnt/root/scripts/*.sh

# Enter Chroot
log "Entering chroot to complete setup..."
arch-chroot /mnt /root/scripts/setup-chroot.sh

log "Installer finished successfully!"
echo "You can now reboot. Log saved at $LOG_FILE"
