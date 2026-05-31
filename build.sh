#!/usr/bin/env bash
set -euo pipefail

# --- Settings ---
PROJECT_NAME="waybar-hyprland-setup"
BUILD_DIR="dist"
OUTPUT_FILE="${PROJECT_NAME}.tar.gz"

# Colors
NC='\e[0m'
BOLD='\e[1m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
YELLOW='\e[1;33m'

log() {
    printf "${BLUE}[build]${NC} %s\n" "$*"
}

success() {
    printf "${GREEN}[✔]${NC} %s\n" "$*"
}

# 1. Cleanup
log "Cleaning build environment..."
rm -rf "$BUILD_DIR"
rm -f "$OUTPUT_FILE"

# 2. Create build directory
log "Preparing build directory..."
mkdir -p "$BUILD_DIR"

# 3. List of essential files (based on install.sh)
log "Copying essential files..."

# Main scripts
cp install.sh menu.sh "$BUILD_DIR/"

# Waybar configurations
cp config.jsonc config-bottom.jsonc config-left.jsonc config-screenshot.jsonc style.css "$BUILD_DIR/"

# Waybar helper scripts
cp audio-input.sh audio-output.sh clipboard-history.sh clipboard-listener.sh \
   launcher.sh minimize.sh restart-waybar.sh screenshot.sh \
   spotify-art.sh spotify-info.sh spotify-playstate.sh \
   wallpaper.sh "$BUILD_DIR/"

# Configuration directories
cp -r hypr-config mako-config wofi-config "$BUILD_DIR/"

# Documentation
cp README.md "$BUILD_DIR/" 2>/dev/null || true

# 4. Create package
log "Compressing files into ${OUTPUT_FILE}..."
tar -czf "$OUTPUT_FILE" -C "$BUILD_DIR" .

# 5. Finalization
log "Cleaning temporary directory..."
rm -rf "$BUILD_DIR"

echo -e "\n${GREEN}${BOLD}Build completed successfully!${NC}"
success "Package generated: ${OUTPUT_FILE}"
log "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"
