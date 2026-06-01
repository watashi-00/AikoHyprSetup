#!/usr/bin/env bash

# icon-gen.sh - Generates color-filtered icons for the taskbar
# Usage: ./icon-gen.sh <hex_color> [app_name]

COLOR_INPUT="$1"
APP_NAME="$2"

# Paths
BASE_CACHE_DIR="$HOME/.config/waybar/cache/icons"
COLOR_HEX=$(echo "$COLOR_INPUT" | sed 's/#//g')
COLOR_CACHE_DIR="$BASE_CACHE_DIR/$COLOR_HEX"
TARGET_THEME_DIR="$HOME/.local/share/icons/Aiko"
ICON_SIZE="32x32"
APPS_SUBDIR="$ICON_SIZE/apps"

mkdir -p "$COLOR_CACHE_DIR/$APPS_SUBDIR"

# Link theme folder to current color cache
if [ "$(readlink -f "$TARGET_THEME_DIR")" != "$(readlink -f "$COLOR_CACHE_DIR")" ]; then
    rm -rf "$TARGET_THEME_DIR"
    ln -s "$COLOR_CACHE_DIR" "$TARGET_THEME_DIR"
fi

# Ensure index.theme exists
if [ ! -f "$COLOR_CACHE_DIR/index.theme" ]; then
    cat <<EOF > "$COLOR_CACHE_DIR/index.theme"
[Icon Theme]
Name=Aiko
Comment=Dynamic Aiko Icon Theme
Directories=$APPS_SUBDIR

[$APPS_SUBDIR]
Size=32
Context=Applications
Type=Fixed
EOF
fi

map_class_to_icon() {
    local class="${1,,}"
    case "$class" in
        "com.discordapp.discord"|"discord") echo "discord" ;;
        "firefox"|"firefox-esr") echo "firefox" ;;
        "google-chrome"|"google-chrome-stable") echo "google-chrome" ;;
        "code-oss"|"vscode") echo "code" ;;
        "org.gnome.nautilus"|"thunar") echo "system-file-manager" ;;
        "kitty") echo "terminal" ;;
        "spotify") echo "spotify" ;;
        *) echo "$class" ;;
    esac
}

find_icon_path() {
    local name="$1"
    local search_dirs=(
        "$HOME/.local/share/icons"
        "/usr/share/icons"
        "/usr/share/pixmaps"
    )
    # Search for SVG first for better quality, then PNG
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        # Prefer 'apps' or 'scalable' folders
        local found=$(find "$dir" -name "$name.svg" -o -name "$name.png" 2>/dev/null | grep -E "apps|scalable" | head -n 1)
        if [ -n "$found" ]; then echo "$found"; return 0; fi
    done
    return 1
}

process_icon() {
    local app_input="$1"
    [ -z "$app_input" ] && return 1
    local output_file="$COLOR_CACHE_DIR/$APPS_SUBDIR/$app_input.png"
    
    # Skip if already exists in this color folder
    [ -f "$output_file" ] && return 0

    local icon_name=$(map_class_to_icon "$app_input")
    local icon_path=$(find_icon_path "$icon_name")

    if [ -n "$icon_path" ]; then
        # CRITICAL FIX: -background none MUST come before the input file for SVGs
        # Using the tint logic you preferred
        magick -background none "$icon_path" -resize 32x32 -colorspace gray -fill "$COLOR_INPUT" -tint 100 "$output_file" 2>/dev/null
    else
        # Fallback D
        local letter=$(echo "${app_input:0:1}" | tr '[:lower:]' '[:upper:]' | head -c 1)
        magick -size 32x32 xc:none -fill "$COLOR_INPUT" -draw "roundrectangle 2,2 30,30 8,8" \
               -fill white -pointsize 20 -gravity center -annotate +0+0 "$letter" \
               "$output_file" 2>/dev/null
    fi
}

if [ -n "$APP_NAME" ]; then
    process_icon "$APP_NAME"
else
    RUNNING_APPS=$(hyprctl clients -j | jq -r '.[].class' | tr '[:upper:]' '[:lower:]' | sort -u)
    COMMON_APPS="firefox discord kitty thunar code spotify google-chrome"
    ALL_APPS=$(echo "$RUNNING_APPS $COMMON_APPS" | tr ' ' '\n' | sort -u)
    for a in $ALL_APPS; do process_icon "$a"; done
fi
