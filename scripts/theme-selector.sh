#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [ -f "$SCRIPT_DIR/../aiko-ideas.md" ]; then
    # Case: Running from the repository
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    WAYBAR_STYLE="$REPO_DIR/waybar/style.css"
    LINK_PREFIX="../themes"
else
    # Case: Running from ~/.config/waybar
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        REPO_DIR="$SCRIPT_DIR"
    fi
    WAYBAR_STYLE="$REPO_DIR/style.css"
    LINK_PREFIX="themes"
fi

THEMES_DIR="$REPO_DIR/themes"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
WOFI_STYLE="$HOME/.config/wofi/style.css"
MAKO_CONF="$HOME/.config/mako/config"

# --- Utils ---
log() { printf "\e[34m[theme]\e[0m %s\n" "$*"; }
error() { printf "\e[31m[error]\e[0m %s\n" "$*" >&2; }

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
ln -sf "$LINK_PREFIX/$(basename "$selected_file")" "$WAYBAR_STYLE"

# --- 2. Dynamic Patcher (The "100% Editable" Engine) ---
# This engine looks for lines ending with '@theme:tag' and updates them 
# with values defined as '@tag: value' in the theme header.

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
            # Escape value for sed
            local escaped_value=$(echo "$value" | sed 's/[\/&]/\\&/g')
            # The regex handles both shell-style (#) and CSS-style (/* */) comments
            # It preserves the leading indentation and the setting name
            sed -i "s|^\([[:space:]]*\)\([^#/\n]*\)\([#/;*]*\)[[:space:]]*$marker|\1\2\3 $value $marker|g" "$file"
            
            # Second pass to fix double assignments if the line already had a value
            # (Matches 'setting = old_val # @theme:tag' and replaces old_val)
            # This is complex, so we use a simpler approach: 
            # Capture everything until the assignment operator (= or :) and then put the new value
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
# Explicitly patch known config files
patch_file "$HYPR_CONF"
patch_file "$MAKO_CONF"
patch_file "$WOFI_STYLE"

# --- 4. Widget Theme Mapping ---
log "Updating widgets..."
grep "@widget-" "$selected_file" | while read -r line; do
    var_part=$(echo "$line" | cut -d':' -f1 | tr -d '[:space:]*')
    widget_name=${var_part#@widget-}
    theme_file=$(echo "$line" | cut -d':' -f2- | sed 's/^ //;s/[[:space:]]*$//')

    if [ -n "$widget_name" ] && [ -n "$theme_file" ]; then
        widget_dir="$REPO_DIR/widgets/$widget_name"
        if [ -d "$widget_dir" ]; then
            source_theme="$widget_dir/themes/$theme_file"
            if [ -f "$source_theme" ]; then
                log "Linking theme for $widget_name: $theme_file"
                rm -f "$widget_dir/theme.css"
                ln -sf "themes/$theme_file" "$widget_dir/theme.css"
            fi
        fi
    fi
done

# --- 5. Icon Generation ---
accent_color=$(grep "@mako-border" "$selected_file" | cut -d':' -f2 | tr -d '[:space:]')
[ -z "$accent_color" ] && accent_color="#ff8fbd"
if [ -f "$REPO_DIR/scripts/icon-gen.sh" ]; then
    log "Generating themed icons..."
    bash "$REPO_DIR/scripts/icon-gen.sh" "$accent_color"
fi

# --- 6. Sync and Refresh ---
# Only copy if we are not already in the target directory
if [ "$(realpath -m "$WAYBAR_STYLE")" != "$(realpath -m "$HOME/.config/waybar/style.css")" ]; then
    cp -d "$WAYBAR_STYLE" "$HOME/.config/waybar/style.css"
fi

if command -v hyprctl >/dev/null 2>&1; then hyprctl reload >/dev/null 2>&1 || true; fi
if command -v makoctl >/dev/null 2>&1; then makoctl reload >/dev/null 2>&1 || true; fi

# Automatically restart Waybar to apply new theme
RESTART_SCRIPT="$REPO_DIR/scripts/restart-waybar.sh"
if [ -f "$RESTART_SCRIPT" ]; then
    bash "$RESTART_SCRIPT"
fi

log "Global theme applied successfully!"
