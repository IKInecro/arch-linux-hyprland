#!/bin/bash

# auto-grub-config.sh - Ultimate Arch Linux GRUB Automation & Self-Healing Script
# Purpose: Fully automated GRUB setup with dual-boot and theme support.
# Author: Antigravity AI

set -e

# --- Configuration & Global Variables ---
LOG_FILE="/var/log/arch-auto-grub.log"
THEME_URL="https://github.com/Priyank-Adhav/Matrix-Morpheus-GRUB-Theme"
THEME_NAME="Matrix-Morpheus"
THEME_DIR="/boot/grub/themes/$THEME_NAME"
RETRIES=3

# --- Helper Functions ---

log() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "\e[1;32m[$timestamp]\e[0m $1" | tee -a "$LOG_FILE"
}

warn() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "\e[1;33m[$timestamp] WARNING:\e[0m $1" | tee -a "$LOG_FILE"
}

error() {
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "\e[1;31m[$timestamp] ERROR:\e[0m $1" | tee -a "$LOG_FILE" >&2
}

fatal() {
    error "$1"
    log "Aborting process."
    exit 1
}

# Self-healing retry wrapper
run_with_retry() {
    local cmd="$1"
    local description="$2"
    local count=0
    local success=0

    while [ $count -lt $RETRIES ]; do
        log "Attempt $((count+1))/$RETRIES: $description"
        if eval "$cmd"; then
            success=1
            break
        fi
        warn "Command failed: $description. Retrying..."
        ((count++))
        sleep 2
        # Run recovery if provided as 3rd arg
        if [ -n "$3" ]; then
            log "Running recovery function..."
            eval "$3"
        fi
    done

    if [ $success -eq 0 ]; then
        fatal "Failed after $RETRIES attempts: $description"
    fi
}

# --- Detection of Chroot or Root Environment ---

detect_environment() {
    if [ "$(stat -c %d /)" != "$(stat -c %d /..)" ]; then
        log "Detected running inside a chroot environment."
        CHROOT_MODE=true
        MOUNT_ROOT=""
        MOUNT_EFI="/boot/efi"
    else
        log "Detected running as host/Live USB."
        CHROOT_MODE=false
        MOUNT_ROOT="/mnt"
        MOUNT_EFI="$MOUNT_ROOT/boot/efi"
    fi
}

# --- System Detection ---

check_uefi() {
    log "Checking for UEFI mode..."
    if [ ! -d "/sys/firmware/efi" ]; then
        fatal "System is NOT running in UEFI mode. This script requires UEFI."
    fi
    log "UEFI mode detected."
}

detect_root() {
    if [ "$CHROOT_MODE" = true ]; then
        ROOT_PART=$(findmnt -n -o SOURCE /)
        log "In chroot, root partition is: $ROOT_PART"
        return
    fi

    log "Detecting root partition..."
    local root_dev=""

    # 1. Try label ARCH_ROOT
    root_dev=$(lsblk -rn -o NAME,LABEL | grep "ARCH_ROOT" | awk '{print $1}')

    # 2. Scan for Linux root if label not found
    if [ -z "$root_dev" ]; then
        warn "Partition with label ARCH_ROOT not found. Scanning for Linux partitions..."
        local candidates=($(lsblk -rn -o NAME,FSTYPE | grep "ext4\|btrfs\|xfs" | awk '{print $1}'))
        
        if [ ${#candidates[@]} -eq 1 ]; then
            root_dev=${candidates[0]}
            log "Automatically selected unique candidate: /dev/$root_dev"
        elif [ ${#candidates[@]} -gt 1 ]; then
            error "Multiple Linux partitions found: ${candidates[*]}"
            fatal "Please label your root partition as ARCH_ROOT or specify it manually."
        else
            fatal "Could not detect any Linux root partition candidate."
        fi
    fi

    ROOT_PART="/dev/$root_dev"
    log "Using root partition: $ROOT_PART"
}

detect_efi() {
    if [ "$CHROOT_MODE" = true ] && mountpoint -q /boot/efi; then
         EFI_PART=$(findmnt -n -o SOURCE /boot/efi)
         log "In chroot, EFI partition is: $EFI_PART"
         return
    fi

    log "Detecting EFI partition..."
    local efi_dev=""

    # 1. PARTLABEL EFI
    efi_dev=$(lsblk -rn -o NAME,PARTLABEL | grep -i "EFI" | awk '{print $1}' | head -n 1)

    # 2. Flag EFI (Type 0xEF00 or EF)
    if [ -z "$efi_dev" ]; then
        efi_dev=$(lsblk -rn -o NAME,PARTTYPE | grep -i "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" | awk '{print $1}' | head -n 1)
    fi

    # 3. Existing mount
    if [ -z "$efi_dev" ] && mountpoint -q /boot/efi; then
        efi_dev=$(findmnt -n -o SOURCE /boot/efi)
    fi

    if [ -z "$efi_dev" ]; then
        fatal "Could not detect EFI partition. Please ensure it has PARTLABEL='EFI' or correct EFI flags."
    fi

    # Handle if /dev/ prefix is missing
    if [[ ! "$efi_dev" =~ ^/dev/ ]]; then
        efi_dev="/dev/$efi_dev"
    fi

    EFI_PART="$efi_dev"
    log "Using EFI partition: $EFI_PART"
}

# --- Mounting ---

mount_recovery() {
    if [ "$CHROOT_MODE" = true ]; then
        warn "Mount recovery in chroot: just ensuring /boot/efi is mounted..."
        mount -a || true
        return
    fi
    log "Performing mount recovery: unmounting all and cleaning up..."
    umount -R "$MOUNT_ROOT" 2>/dev/null || true
    mkdir -p "$MOUNT_ROOT"
}

perform_mount() {
    if [ "$CHROOT_MODE" = true ]; then
        log "In chroot, ensuring /boot/efi is mounted..."
        mkdir -p /boot/efi
        if ! mountpoint -q /boot/efi; then
             run_with_retry "mount $EFI_PART /boot/efi" "Mounting EFI to /boot/efi"
        fi
        return
    fi

    log "Mounting partitions..."
    # Root
    if ! mountpoint -q "$MOUNT_ROOT"; then
        run_with_retry "mount $ROOT_PART $MOUNT_ROOT" "Mounting root to $MOUNT_ROOT" mount_recovery
    fi

    # EFI
    mkdir -p "$MOUNT_EFI"
    if ! mountpoint -q "$MOUNT_EFI"; then
        run_with_retry "mount $EFI_PART $MOUNT_EFI" "Mounting EFI to $MOUNT_EFI" mount_recovery
    fi
}

# --- Package Management ---

fix_pacman_lock() {
    if [ -f "/var/lib/pacman/db.lck" ]; then
        warn "Pacman database is locked. Removing /var/lib/pacman/db.lck..."
        rm -f /var/lib/pacman/db.lck
    fi
}

install_packages() {
    log "Checking required packages..."
    local pkgs=(grub efibootmgr os-prober git)
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [ ${#to_install[@]} -gt 0 ]; then
        log "Installing missing packages: ${to_install[*]}"
        fix_pacman_lock
        run_with_retry "pacman -Sy --noconfirm ${to_install[*]}" "Installing packages" fix_pacman_lock
    else
        log "All required packages are already installed."
    fi
}

# --- Bootloader Setup ---

grub_install_recovery() {
    warn "Grub install failed. Attempting remount recovery..."
    umount "$MOUNT_EFI" 2>/dev/null || true
    mount "$EFI_PART" "$MOUNT_EFI"
}

setup_grub() {
    log "Running grub-install..."
    
    local install_cmd
    if [ "$CHROOT_MODE" = true ]; then
        install_cmd="grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck"
    else
        mkdir -p "$MOUNT_ROOT/etc/default"
        mkdir -p "$MOUNT_ROOT/boot/grub"
        install_cmd="grub-install --target=x86_64-efi --efi-directory=$MOUNT_EFI --bootloader-id=GRUB --recheck --root-directory=$MOUNT_ROOT"
    fi
    
    run_with_retry "$install_cmd" "Executing grub-install" grub_install_recovery
}

# --- OS Detection (Dual Boot) ---

configure_os_prober() {
    log "Configuring os-prober for dual-boot..."
    local grub_config="$MOUNT_ROOT/etc/default/grub"

    if [ ! -f "$grub_config" ] && [ "$CHROOT_MODE" = true ]; then
         grub_config="/etc/default/grub"
    fi

    if [ ! -f "$grub_config" ]; then
        warn "GRUB config file $grub_config not found. Creating a basic one..."
        mkdir -p "$(dirname "$grub_config")"
        echo 'GRUB_DEFAULT=0' > "$grub_config"
        echo 'GRUB_TIMEOUT=5' >> "$grub_config"
        echo 'GRUB_DISTRIBUTOR="Arch"' >> "$grub_config"
    fi

    if grep -q "GRUB_DISABLE_OS_PROBER" "$grub_config"; then
        sed -i 's/.*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$grub_config"
    else
        echo "GRUB_DISABLE_OS_PROBER=false" >> "$grub_config"
    fi
    log "os-prober enabled in $grub_config"
}

# --- Theme Setup ---

install_theme() {
    log "Setting up Matrix Morpheus theme..."
    local host_theme_dir="$MOUNT_ROOT$THEME_DIR"
    mkdir -p "$(dirname "$host_theme_dir")"

    if [ ! -d "$host_theme_dir" ]; then
        run_with_retry "git clone $THEME_URL $host_theme_dir" "Cloning Matrix theme"
    else
        log "Theme directory already exists. Validating..."
        if [ ! -f "$host_theme_dir/theme.txt" ]; then
            warn "theme.txt missing. Re-cloning..."
            rm -rf "$host_theme_dir"
            git clone "$THEME_URL" "$host_theme_dir"
        fi
    fi

    # Set theme in GRUB config
    local grub_config="$MOUNT_ROOT/etc/default/grub"
    if [ "$CHROOT_MODE" = true ] && [ ! -f "$grub_config" ]; then
        grub_config="/etc/default/grub"
    fi

    if grep -q "GRUB_THEME=" "$grub_config"; then
        sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" "$grub_config"
    else
        echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" >> "$grub_config"
    fi
}

# --- Permissions & Final Config ---

fix_permissions() {
    log "Fixing permissions and directories..."
    local sudoers_dir="$MOUNT_ROOT/etc/sudoers.d"
    if [ "$CHROOT_MODE" = true ] && [ ! -d "$sudoers_dir" ]; then
        sudoers_dir="/etc/sudoers.d"
    fi

    mkdir -p "$sudoers_dir"
    run_with_retry "chmod 750 $sudoers_dir" "Setting sudoers.d permissions"
}

generate_config() {
    log "Generating final GRUB configuration..."
    
    if [ "$CHROOT_MODE" = true ]; then
        grub-mkconfig -o /boot/grub/grub.cfg
    elif command -v arch-chroot &>/dev/null; then
        log "Running grub-mkconfig inside arch-chroot..."
        arch-chroot "$MOUNT_ROOT" grub-mkconfig -o /boot/grub/grub.cfg
    else
        warn "arch-chroot not found. Attempting manual config generation..."
        grub-mkconfig -o "$MOUNT_ROOT/boot/grub/grub.cfg"
    fi

    local target_cfg="$MOUNT_ROOT/boot/grub/grub.cfg"
    if [ "$CHROOT_MODE" = true ]; then target_cfg="/boot/grub/grub.cfg"; fi

    # Validation: Check for Windows
    if grep -qi "Windows" "$target_cfg"; then
        log "Windows Boot Manager detected successfully."
    else
        warn "Windows NOT detected in grub.cfg."
    fi
}

# --- Main Execution ---

main() {
    log "=== Starting Arch Linux GRUB Automation Script ==="
    
    detect_environment
    check_uefi
    detect_root
    detect_efi
    perform_mount
    install_packages
    setup_grub
    configure_os_prober
    install_theme
    fix_permissions
    generate_config
    
    log "=== GRUB Installation Finished Successfully! ==="
}

# Initialize Log
[ "$EUID" -eq 0 ] && echo "--- Arch Auto GRUB Log Start ---" > "$LOG_FILE"

# Run main with elevation check
if [ "$EUID" -ne 0 ]; then
    fatal "Please run this script as root (sudo)."
fi

main
