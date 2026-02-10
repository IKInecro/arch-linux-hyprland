#!/bin/bash

# scripts/validation-check.sh - Post-Install Validation
# Description: Verifies system readiness for first boot.

set -e
LOG_FILE="/var/log/arch-auto-install.log"

log() {
    echo -e "\033[0;32m[$(date +'%H:%M:%S')] $1\033[0m" | tee -a "$LOG_FILE"
}

error() {
    echo -e "\033[0;31m[$(date +'%H:%M:%S')] ERROR: $1\033[0m" | tee -a "$LOG_FILE"
    exit 1
}

log "Running Final System Validation..."

# 1. Verification of EFI Files
if [ ! -f "/boot/efi/EFI/BOOT/BOOTX64.EFI" ]; then
    error "Validation failed: Removable GRUB binary missing."
fi

# 2. Verification of grub.cfg
if [ ! -s "/boot/grub/grub.cfg" ]; then
    error "Validation failed: grub.cfg is empty or missing."
fi

# 3. Verification of system foundation
if [ ! -f "/etc/hostname" ]; then
    error "Validation failed: System configuration not applied."
fi

# 4. Check for Windows in grub.cfg (Warning only)
if ! grep -q "Windows Boot Manager" /boot/grub/grub.cfg; then
    log "WARNING: os-prober did not find Windows. You might need to manual probe later."
else
    log "SUCCESS: Windows detected by GRUB."
fi

log "Validation passed! System is ready to boot."
exit 0
