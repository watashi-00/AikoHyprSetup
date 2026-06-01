#!/usr/bin/env bash

# icon-gen.sh - Generates color-filtered icons for the taskbar
# Usage: ./icon-gen.sh <hex_color> [app_name]

COLOR="$1"
APP_NAME="$2"
CACHE_DIR="$HOME/.local/share/icons/Aiko"
ICON_SIZE="32x32"
APPS_DIR="$CACHE_DIR/$ICON_SIZE/apps"
COLOR_CACHE="$HOME/.config/waybar/cache/icons/current_color"

# If color is not provided, try to read from cache
if [ -z "$COLOR" ]; then
    if [ -f "$COLOR_CACHE" ]; then
        COLOR=$(cat "$COLOR_CACHE")
    else
        exit 1
    fi
fi

mkdir -p "$(dirname "$COLOR_CACHE")"
echo "$COLOR" > "$COLOR_CACHE"
mkdir -p "$APPS_DIR"

# Create index.theme if it doesn't exist
if [ ! -f "$CACHE_DIR/index.theme" ]; then
    cat <<EOF > "$CACHE_DIR/index.theme"
[Icon Theme]
Name=Aiko
Comment=Dynamic Aiko Icon Theme
Directories=$ICON_SIZE/apps

[$ICON_SIZE/apps]
Size=32
Context=Applications
Type=Fixed
EOF
fi

# Better mapping for common app classes to icon names
map_class_to_icon() {
    local class="${1,,}"
    case "$class" in
        "com.discordapp.discord"|"discord") echo "discord" ;;
        "firefox"|"firefox-esr") echo "firefox" ;;
        "google-chrome"|"google-chrome-stable") echo "google-chrome" ;;
        "code-oss"|"vscode") echo "code" ;;
        "org.gnome.nautilus"|"thunar") echo "system-file-manager" ;;
        "kitty") echo "terminal" ;;
        *) echo "$class" ;;
    esac
}

# Function to find and colorize icon
process_icon() {
    local app_input="$1"
    [ -z "$app_input" ] && return 1
    
    local app=$(map_class_to_icon "$app_input")
    local output_file="$APPS_DIR/$app_input.png"
    
    # Try multiple search strategies
    local icon_path=""
    
    # 1. Direct match in system icons
    icon_path=$(find /usr/share/icons -name "$app.png" -o -name "$app.svg" | grep -E "apps|48x48|scalable" | head -n 1)
    
    # 2. Search by desktop file
    if [ -z "$icon_path" ]; then
        local desktop_file=$(find /usr/share/applications -name "*$app*.desktop" | head -n 1)
        if [ -n "$desktop_file" ]; then
            local icon_name=$(grep "^Icon=" "$desktop_file" | cut -d'=' -f2)
            if [ -n "$icon_name" ]; then
                if [[ "$icon_name" == /* ]]; then
                    icon_path="$icon_name"
                else
                    icon_path=$(find /usr/share/icons -name "$icon_name.png" -o -name "$icon_name.svg" | head -n 1)
                fi
            fi
        fi
    fi

    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        # Colorize existing icon
        magick "$icon_path" -resize 32x32 -colorspace gray -fill "$COLOR" -tint 100 "$output_file" 2>/dev/null
    else
        # FALLBACK: Generate a stylized placeholder icon if nothing is found
        local letter=$(echo "${app_input:0:1}" | tr '[:lower:]' '[:upper:]' | head -c 1)
        magick -size 32x32 xc:none -fill "$COLOR" -draw "roundrectangle 2,2 30,30 8,8" \
               -fill white -pointsize 20 -gravity center -annotate +0+0 "$letter" \
               "$output_file" 2>/dev/null
    fi
}

if [ -n "$APP_NAME" ]; then
    process_icon "$APP_NAME"
else
    # Full regeneration
    RUNNING_APPS=$(hyprctl clients -j | jq -r '.[].class' | tr '[:upper:]' '[:lower:]' | sort -u)
    COMMON_APPS="firefox discord kitty thunar code spotify"
    ALL_APPS=$(echo "$RUNNING_APPS $COMMON_APPS" | tr ' ' '\n' | sort -u)
    
    for a in $ALL_APPS; do
        process_icon "$a"
    done
fi
