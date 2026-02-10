# Arch Linux FULL AUTO Modular Installer

A stable, idempotent, and self-healing installer for Arch Linux with Hyprland, optimized for dual-boot configurations.

## The Full Auto Advantage
The installer is now fully automated. Simply run one script, and it orchestrates the entire process including system foundation, dual-boot bootloader, and post-installation validation.

## Requirements
- **UEFI Mode**: Must be booted in UEFI mode.
- **Partition Label**: The target root partition MUST be labeled `ARCH_ROOT`.
- **Internet**: Active internet connection required.

## Usage
Boot into the Arch ISO, ensure your target partition is labeled `ARCH_ROOT`, then run:
```bash
chmod +x auto-install.sh
bash auto-install.sh
```

## Features
- **Zero Interaction**: Runs all steps (System, GRUB, Validation) automatically.
- **Self-Healing Bootloader**: Uses `--removable` path to ensure motherboard priority.
- **Dual Boot**: Automatic `os-prober` and theme setup.
- **Pre-Boot Validation**: Ensures that the system is boot-ready before completing.

## Technical Details
- **Root**: `/mnt` (mapped to `ARCH_ROOT`)
- **EFI**: `/mnt/boot/efi`
- **Default User**: `JAWA` (Password: `123`)
- **Matrix Theme**: Applied automatically to GRUB.
- **Log**: `/var/log/arch-auto-install.log`.
