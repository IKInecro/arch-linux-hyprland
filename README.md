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
