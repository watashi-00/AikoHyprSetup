#!/usr/bin/env bash
# widgets/aiko-audio/install_drivers.sh - Install headphone drivers and fixes
set -euo pipefail

# Ensure we are running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with pkexec." >&2
    exit 1
fi

echo "Installing headphone drivers and compatibility fixes..."

# 1. Install packages based on PM
if command -v pacman >/dev/null 2>&1; then
    echo "Arch Linux detected. Installing firmware packages..."
    pacman -S --needed --noconfirm sof-firmware alsa-firmware alsa-ucm-conf
elif command -v apt-get >/dev/null 2>&1; then
    echo "Debian/Ubuntu detected. Installing firmware packages..."
    apt-get update
    apt-get install -y firmware-sof-signed alsa-ucm-conf
else
    echo "Unknown package manager. Skipping firmware package installation."
fi

# 2. Add modprobe options for snd-hda-intel
MODPROBE_FILE="/etc/modprobe.d/aiko-audio.conf"
echo "Writing ALSA options to $MODPROBE_FILE..."
mkdir -p "$(dirname "$MODPROBE_FILE")"
cat << 'EOF' > "$MODPROBE_FILE"
# Configured by Aiko Audio Manager
options snd-hda-intel model=headset-mode
EOF

echo "Done! Please restart your computer to apply the hardware driver changes."
