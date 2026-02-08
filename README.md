# Arch Linux Hyprland Auto Installer

Automated Arch Linux installer with Hyprland, tailored for specific hardware configuration.

## Features
- **Automatic Partition Detection**: Finds `fydeos` label partition for Root and Windows EFI for Boot.
- **Base Installation**: Installs Arch Linux base system.
- **Bootloader**: GRUB with OS Prober (Dual Boot support).
- **User Setup**: Creates user `JAWA` with sudo privileges.
- **Desktop Environment**: Hyprland, Waybar, Rofi, Kitty, etc.
- **Dotfiles**: Automatically installs [Caelestia Shell](https://github.com/caelestia-dots/shell).
- **AUR Helper**: Installs `paru`.

## Prerequisites
- **Arch Linux Installation Media**: Boot from an official Arch ISO.
- **Internet Connection**: Must be connected to the internet.
- **Partition Labels**:
    - Root partition must be labeled `fydeos`.
    - EFI partition must be standard Windows EFI (vfat).

## Usage

1. Boot into Arch Linux live environment.
2. Connect to internet (`wifi-menu` or `station wlan0 connect SSID`).
3. Clone this repository:
   ```bash
   git clone https://github.com/IKInecro/arch-linux-hyprland.git
   cd arch-linux-hyprland
   ```
4. Run the installer:
   ```bash
   chmod +x install-arch.sh
   ./install-arch.sh
   ```
5. Follow the prompts (confirm formatting).
6. Reboot upon completion.

## Logs
Installation logs are saved in `logs/install.log` on the new system.
