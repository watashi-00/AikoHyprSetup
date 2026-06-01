#!/usr/bin/env bash

# icon-gen.sh - Generates color-filtered icons for the taskbar
# Usage: ./icon-gen.sh <hex_color> [app_name]

COLOR_INPUT="${1:-#ff8fbd}"
APP_NAME="$2"

# Paths
BASE_CACHE_DIR="$HOME/.config/waybar/cache/icons"
COLOR_HEX=$(echo "$COLOR_INPUT" | sed 's/#//g')
[ -z "$COLOR_HEX" ] && COLOR_HEX="default"
COLOR_CACHE_DIR="$BASE_CACHE_DIR/$COLOR_HEX"
TARGET_THEME_DIR="$HOME/.local/share/icons/Aiko"
ICON_SIZE="32x32"
APPS_SUBDIR="$ICON_SIZE/apps"

mkdir -p "$COLOR_CACHE_DIR/$APPS_SUBDIR"

# Ensure the global theme link is correct
if [ "$(readlink -f "$TARGET_THEME_DIR")" != "$(readlink -f "$COLOR_CACHE_DIR")" ]; then
    echo "[icon-gen] Linking $TARGET_THEME_DIR to $COLOR_CACHE_DIR"
    rm -rf "$TARGET_THEME_DIR"
    ln -s "$COLOR_CACHE_DIR" "$TARGET_THEME_DIR"
fi

if [ ! -f "$COLOR_CACHE_DIR/index.theme" ]; then
    echo "[icon-gen] Creating index.theme"
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
        "code-oss"|"vscode"|"code") echo "code" ;;
        "org.gnome.nautilus"|"thunar") echo "system-file-manager" ;;
        "kitty") echo "terminal" ;;
        "spotify"|"spotify-client") echo "spotify" ;;
        "org.kde.dolphin"|"dolphin") echo "system-file-manager" ;;
        "org.kde.discover"|"discover") echo "plasmadiscover" ;;
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
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        # Find exactly the name or common variations
        local found=$(find "$dir" -maxdepth 10 \( -name "$name.svg" -o -name "$name.png" -o -name "${name,,}.svg" -o -name "${name,,}.png" \) 2>/dev/null | grep -E "apps|scalable" | head -n 1)
        if [ -n "$found" ]; then echo "$found"; return 0; fi
    done
    return 1
}

process_icon() {
    local app_input="$1"
    [ -z "$app_input" ] && return 1
    
    local variants=("$app_input" "${app_input,,}" "${app_input#org.kde.}")
    local output_file="$COLOR_CACHE_DIR/$APPS_SUBDIR/$app_input.png"
    
    if [ -f "$output_file" ]; then
        echo "[icon-gen] Icon already exists for $app_input"
        return 0
    fi

    local icon_path=""
    for v in "${variants[@]}"; do
        local icon_name=$(map_class_to_icon "$v")
        icon_path=$(find_icon_path "$icon_name")
        [ -n "$icon_path" ] && break
    done

    if [ -n "$icon_path" ]; then
        echo "[icon-gen] Processing $app_input using $icon_path"
        if magick -background none "$icon_path" -resize 32x32 \
               -channel RGB -colorspace gray +channel \
               -fill "$COLOR_INPUT" -tint 100 "$output_file" 2>/dev/null; then
            
            sync "$output_file"
            # Create a lowercase symlink for compatibility (e.g., Spotify -> spotify)
            local lower_name="${app_input,,}"
            if [ "$app_input" != "$lower_name" ]; then
                ln -sf "$(basename "$output_file")" "$(dirname "$output_file")/$lower_name.png"
            fi
            return 200
        else
            echo "[icon-gen] Magick failed for $app_input"
            return 1
        fi
    else
        echo "[icon-gen] No icon found for $app_input, using fallback"
        local letter=$(echo "${app_input:0:1}" | tr '[:lower:]' '[:upper:]' | head -c 1)
        if magick -size 32x32 xc:none -fill "$COLOR_INPUT" -draw "roundrectangle 2,2 30,30 8,8" \
               -fill white -pointsize 20 -gravity center -annotate +0+0 "$letter" \
               "$output_file" 2>/dev/null; then
            
            # Create a lowercase symlink for fallback too
            local lower_name="${app_input,,}"
            if [ "$app_input" != "$lower_name" ]; then
                ln -sf "$(basename "$output_file")" "$(dirname "$output_file")/$lower_name.png"
            fi
            return 200
        else
            echo "[icon-gen] Fallback magick failed for $app_input"
            return 1
        fi
    fi
}

if [ -n "$APP_NAME" ]; then
    process_icon "$APP_NAME"
    exit $?
else
    NEW_ICONS=0
    RUNNING_APPS=$(hyprctl clients -j | jq -r '.[].class' | sort -u)
    for a in $RUNNING_APPS; do 
        process_icon "$a"
        [ $? -eq 200 ] && NEW_ICONS=1
    done
    [ $NEW_ICONS -eq 1 ] && exit 200 || exit 0
fi
