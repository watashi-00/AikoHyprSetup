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
mkdir -p "$BUILD_DIR/widgets"

# 2.5 Build Python Widgets
# Try to find pyinstaller (via uv or global)
PYINSTALLER_CMD=""
if command -v uv >/dev/null 2>&1; then
    log "uv detected. Checking for PyInstaller..."
    # Check if pyinstaller tool is installed in uv
    if uv tool list | grep -q "pyinstaller"; then
        PYINSTALLER_CMD="uv tool run pyinstaller"
    else
        log "PyInstaller not found in uv tools. Trying to run via 'uv run'..."
        PYINSTALLER_CMD="uv run pyinstaller"
    fi
elif command -v pyinstaller >/dev/null 2>&1; then
    PYINSTALLER_CMD="pyinstaller"
fi

if [ -n "$PYINSTALLER_CMD" ]; then
    log "Compiling Python widgets with: $PYINSTALLER_CMD"
    
    # Aiko-Note
    if [ -f "widgets/aiko-note/aiko-note.py" ]; then
        log "Compiling Aiko-Note..."
        $PYINSTALLER_CMD --noconfirm --onefile --windowed \
            --name "aiko-note-bin" \
            --distpath "$BUILD_DIR/widgets/aiko-note" \
            --workpath "/tmp/pyinstaller-build" \
            --specpath "/tmp/pyinstaller-specs" \
            "widgets/aiko-note/aiko-note.py"
        
        # Clean up temporary build files
        rm -rf "/tmp/pyinstaller-build" "/tmp/pyinstaller-specs"
    fi
else
    log "${YELLOW}[!] PyInstaller not found. Skipping widget compilation. Python will be required to run them.${NC}"
fi

# 3. Copy essential files
log "Copying essential files..."

# Root files
cp install.sh LICENSE README.md "$BUILD_DIR/"

# Waybar configs
cp waybar/* "$BUILD_DIR/waybar/"

# Scripts
cp scripts/* "$BUILD_DIR/scripts/"

# System configs
cp -r configs/hypr "$BUILD_DIR/configs/"
cp -r configs/mako "$BUILD_DIR/configs/"
cp -r configs/wofi "$BUILD_DIR/configs/"
cp -r configs/applications "$BUILD_DIR/configs/"
cp -r configs/kitty "$BUILD_DIR/configs/"
cp -r configs/fastfetch "$BUILD_DIR/configs/"

# Widgets (Copying everything, excluding python files if binaries exist)
cp -r widgets/* "$BUILD_DIR/widgets/"
find "$BUILD_DIR/widgets" -name "__pycache__" -type d -exec rm -rf {} +

# 4. Create package
log "Compressing files into ${OUTPUT_FILE}..."
tar -czf "$OUTPUT_FILE" -C "$BUILD_DIR" .

# 5. Finalization
log "Cleaning temporary directory..."
rm -rf "$BUILD_DIR"

echo -e "\n${GREEN}${BOLD}Build completed successfully!${NC}"
success "Package generated: ${OUTPUT_FILE}"
log "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"
