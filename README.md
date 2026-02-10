# Arch Linux Hyprland Modular Installer

A stable, idempotent, and modular installer for Arch Linux with Hyprland, optimized for dual-boot configurations.

## Architecture
The installer is split into two specialized parts for maximum reliability:
1. **Step 1: System Foundation** (`install-arch.sh`) - Handles partitioning, mounting, and base system installation.
2. **Step 2: Bootloader & Theme** (`install-grub.sh`) - Handles GRUB installation, dual-boot (os-prober) setup, and the Matrix Morpheus theme.

## Requirements
- **UEFI Mode**: Must be booted in UEFI mode.
- **Partition Label**: The target root partition MUST be labeled `ARCH_ROOT`.
- **Internet**: Active internet connection required.

## Usage

### 1. Base Installation
Boot into Arch ISO, ensure your target partition is labeled `ARCH_ROOT`, then run:
```bash
chmod +x install-arch.sh
./install-arch.sh
```
This will install the base system and desktop environment, then configure essential services.

### 2. Bootloader & Dual Boot
After Step 1 completes, run the bootloader setup:
```bash
chmod +x install-grub.sh
./install-grub.sh
```
This step will:
- Install GRUB and `os-prober`.
- Detect Windows (if present).
- Install the **Matrix Morpheus** theme.
- Generate the final GRUB configuration.

## Key Features
- **Idempotency**: Safely re-run scripts if a step fails; they will skip finished tasks.
- **Safety**: No automatic formatting or partitioning. You control your data.
- **Dual Boot**: Automatic `os-prober` activation for coexist with Windows.
- **Aesthetics**: Pre-configured Matrix-style GRUB theme.

## Troubleshooting
- **Label not found**: Use `e2label /dev/sdX ARCH_ROOT` to label your partition.
- **Windows not in GRUB**: Ensure Windows EFI partition exists and is detectable by `lsblk`.
- **Logs**: Detailed logs are kept at `/var/log/arch-hyprland-install.log`.
