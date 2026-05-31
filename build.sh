#!/usr/bin/env bash
set -euo pipefail

# --- Settings ---
PROJECT_NAME="AikoHyprSetup"
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
mkdir -p "$BUILD_DIR/waybar"
mkdir -p "$BUILD_DIR/scripts"
mkdir -p "$BUILD_DIR/configs"

# 3. Copy essential files
log "Copying essential files..."

# Root files
cp install.sh LICENSE README.md "$BUILD_DIR/"

# Waybar configs
cp waybar/* "$BUILD_DIR/waybar/"

# Scripts
cp scripts/* "$BUILD_DIR/scripts/"

# System configs
cp -r configs/* "$BUILD_DIR/configs/"

# 4. Create package
log "Compressing files into ${OUTPUT_FILE}..."
tar -czf "$OUTPUT_FILE" -C "$BUILD_DIR" .

# 5. Finalization
log "Cleaning temporary directory..."
rm -rf "$BUILD_DIR"

echo -e "\n${GREEN}${BOLD}Build completed successfully!${NC}"
success "Package generated: ${OUTPUT_FILE}"
log "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"
