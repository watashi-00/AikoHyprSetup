#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# --- Load Central Utility Library ---
LIB_UTILS="$SCRIPT_DIR/lib/utils.sh"
if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="theme"

# Path logic standardized
WAYBAR_STYLE="$AIKO_ROOT/style.css"
if [ -f "$AIKO_ROOT/waybar/style.css" ]; then
    WAYBAR_STYLE="$AIKO_ROOT/waybar/style.css"
    LINK_PREFIX="../themes"
else
    LINK_PREFIX="themes"
fi

THEMES_DIR="$AIKO_THEMES"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
WOFI_STYLE="$HOME/.config/wofi/style.css"
MAKO_CONF="$HOME/.config/mako/config"

# --- Selection ---
[ ! -d "$THEMES_DIR" ] && error "Themes directory not found" && exit 1
themes=($(ls "$THEMES_DIR"/*.css 2>/dev/null))
[ ${#themes[@]} -eq 0 ] && error "No themes found" && exit 1

options=""
for t in "${themes[@]}"; do
    name=$(grep "@name:" "$t" | cut -d':' -f2 | sed 's/^ //')
    [ -z "$name" ] && name=$(basename "$t" .css)
    options+="$name\n"
done

selected_name=$(echo -e "$options" | wofi --dmenu --prompt "Select Theme" --width 300 --height 350)
[ -z "$selected_name" ] && exit 0

selected_file=""
for t in "${themes[@]}"; do
    name=$(grep "@name:" "$t" | cut -d':' -f2 | sed 's/^ //')
    [ -z "$name" ] && name=$(basename "$t" .css)
    if [ "$name" = "$selected_name" ]; then selected_file="$t"; break; fi
done
[ -z "$selected_file" ] && error "Theme not found" && exit 1

log "Applying theme: $selected_name"

# --- 1. Apply Waybar Style (Relative Symlink) ---
rm -f "$WAYBAR_STYLE"
# cd into waybar dir to ensure relative link is correct
(cd "$(dirname "$WAYBAR_STYLE")" && ln -sf "$LINK_PREFIX/$(basename "$selected_file")" "$(basename "$WAYBAR_STYLE")")

# --- 2. Dynamic Patcher (The "100% Editable" Engine) ---
patch_file() {
    local file="$1"
    [ -f "$file" ] || return 0
    
    log "Patching: $(basename "$file")"
    
    # Extract all markers from the target file
    local markers=$(grep -o "@theme:[a-zA-Z0-9_-]*" "$file" | sort -u)
    
    for marker in $markers; do
        local tag=${marker#@theme:}
        # Find the value in the theme file header
        local value=$(grep "@$tag:" "$selected_file" | cut -d':' -f2- | sed 's/^ //;s/[[:space:]]*$//')
        
        if [ -n "$value" ]; then
            if [[ "$file" == *"config.jsonc" ]]; then
                sed -i "/$marker/s/color=['\"][^'\"]*['\"]/color='$value'/g" "$file"
            fi
            if grep -q "=" "$file"; then
                sed -i "s|^\([[:space:]]*[a-zA-Z0-9._-]*[[:space:]]*=[[:space:]]*\)[^#]*$marker|\1$value # $marker|g" "$file"
            fi
            if grep -q ":" "$file" && [[ "$file" == *.css ]]; then
                 sed -i "s|^\([[:space:]]*[a-zA-Z0-9._-]*[[:space:]]*:[[:space:]]*\)[^;]*;[[:space:]]*/\* $marker \*/|\1$value; /* $marker */|g" "$file"
            fi
        fi
    done
}

# --- 3. Apply Config Patches ---
patch_file "$HYPR_CONF"
patch_file "$MAKO_CONF"
patch_file "$WOFI_STYLE"

if [ -f "$AIKO_ROOT/waybar/config.jsonc" ]; then
    patch_file "$AIKO_ROOT/waybar/config.jsonc"
fi
if [ -f "$AIKO_ROOT/config.jsonc" ]; then
    patch_file "$AIKO_ROOT/config.jsonc"
fi

# --- 4. Widget Theme Mapping ---
log "Updating widgets..."
grep "@widget-" "$selected_file" | while read -r line; do
    var_part=$(echo "$line" | cut -d':' -f1 | tr -d '[:space:]*')
    widget_name=${var_part#@widget-}
    theme_file=$(echo "$line" | cut -d':' -f2- | sed 's/^ //;s/[[:space:]]*$//')

    if [ -n "$widget_name" ] && [ -n "$theme_file" ]; then
        widget_dir="$AIKO_WIDGETS/$widget_name"
        if [ -d "$widget_dir" ]; then
            source_theme="$widget_dir/themes/$theme_file"
            if [ -f "$source_theme" ]; then
                log "Linking theme for $widget_name: $theme_file"
                rm -f "$widget_dir/theme.css"
                (cd "$widget_dir" && ln -sf "themes/$theme_file" "theme.css")
                
                # Update installed widget's theme link if running from repo
                INSTALLED_WIDGET_DIR="$HOME/.config/waybar/widgets/$widget_name"
                if [ "$AIKO_ROOT" != "$HOME/.config/waybar" ] && [ -d "$INSTALLED_WIDGET_DIR" ]; then
                    rm -f "$INSTALLED_WIDGET_DIR/theme.css"
                    (cd "$INSTALLED_WIDGET_DIR" && ln -sf "themes/$theme_file" "theme.css")
                fi
            fi
        fi
    fi
done

# --- 5. Icon Generation ---
accent_color=$(grep "@mako-border" "$selected_file" | cut -d':' -f2 | tr -d '[:space:]')
[ -z "$accent_color" ] && accent_color="#ff8fbd"
if [ -f "$AIKO_SCRIPTS/icon-gen.sh" ]; then
    log "Generating themed icons..."
    bash "$AIKO_SCRIPTS/icon-gen.sh" "$accent_color"
fi

if [ -f "$AIKO_SCRIPTS/sync-fastfetch.py" ]; then
    log "Syncing Fastfetch logo colors..."
    python3 "$AIKO_SCRIPTS/sync-fastfetch.py"
fi

# --- 6. Sync and Refresh ---
INSTALLED_STYLE="$HOME/.config/waybar/style.css"
if [ "$(realpath -m "$WAYBAR_STYLE")" != "$(realpath -m "$INSTALLED_STYLE")" ]; then
    rm -f "$INSTALLED_STYLE"
    (cd "$HOME/.config/waybar" && ln -sf "themes/$(basename "$selected_file")" "style.css")
fi

if have hyprctl; then hyprctl reload >/dev/null 2>&1 || true; fi
if have makoctl; then makoctl reload >/dev/null 2>&1 || true; fi

# Automatically restart Waybar and Widgets to apply new theme
RESTART_SCRIPT="$AIKO_SCRIPTS/restart-waybar.sh"
if [ -f "$RESTART_SCRIPT" ]; then
    bash "$RESTART_SCRIPT"
fi

log "Global theme applied successfully!"
