#!/usr/bin/env bash
set -euo pipefail

# --- Settings ---
PROJECT_NAME="AikoHyprSetup"
SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
BUILD_DIR="dist/${PROJECT_NAME}"
OUTPUT_FILE="${PROJECT_NAME}-${SHORT_SHA}.tar.gz"

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
rm -rf "dist"
rm -f "${PROJECT_NAME}-"*.tar.gz

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

# Use cp -a to preserve symlinks and copy directories recursively
cp -a configs scripts themes waybar widgets assets install.sh README.md LICENSE "$BUILD_DIR/" 2>/dev/null || true

# Remove __pycache__ just in case
find "$BUILD_DIR" -name "__pycache__" -type d -exec rm -rf {} +

# 4. Create package
log "Compressing files into ${OUTPUT_FILE}..."
cd dist
tar -czf "../$OUTPUT_FILE" "${PROJECT_NAME}"
cd ..

# 5. Finalization
log "Cleaning temporary directory..."
rm -rf "dist"

echo -e "\n${GREEN}${BOLD}Build completed successfully!${NC}"
success "Package generated: ${OUTPUT_FILE}"
log "Package size: $(du -h "$OUTPUT_FILE" | cut -f1)"
