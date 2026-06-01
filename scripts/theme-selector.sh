#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
# Get the real directory of the script, resolving symlinks
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

if [ -f "$SCRIPT_DIR/../aiko-ideas.md" ]; then
    # Case: Running from the repository (scripts/ folder)
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    THEMES_DIR="$REPO_DIR/themes"
    WAYBAR_STYLE="$REPO_DIR/waybar/style.css"
    HYPR_CONF="$REPO_DIR/configs/hypr/hyprland.conf"
    WOFI_STYLE="$REPO_DIR/configs/wofi/style.css"
    MAKO_CONF="$REPO_DIR/configs/mako/config"
else
    # Case: Running from ~/.config/waybar
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        REPO_DIR="$SCRIPT_DIR"
    fi
    THEMES_DIR="$REPO_DIR/themes"
    WAYBAR_STYLE="$REPO_DIR/style.css"
    HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
    WOFI_STYLE="$HOME/.config/wofi/style.css"
    MAKO_CONF="$HOME/.config/mako/config"
fi

# --- Utils ---
log() {
    printf "\e[34m[theme]\e[0m %s\n" "$*"
}

error() {
    printf "\e[31m[error]\e[0m %s\n" "$*" >&2
}

# --- Selection ---
if [ ! -d "$THEMES_DIR" ]; then
    error "Themes directory not found: $THEMES_DIR"
    exit 1
fi

themes=($(ls "$THEMES_DIR"/*.css 2>/dev/null))
if [ ${#themes[@]} -eq 0 ]; then
    error "No themes found in $THEMES_DIR"
    exit 1
fi

options=""
for t in "${themes[@]}"; do
    name=$(grep "@name:" "$t" | cut -d':' -f2 | sed 's/^ //')
    [ -z "$name" ] && name=$(basename "$t" .css)
    options+="$name\n"
done

if command -v wofi >/dev/null 2>&1; then
    selected_name=$(echo -e "$options" | wofi --dmenu --prompt "Select Theme" --width 300 --height 350)
else
    echo "Available themes:"
    echo -e "$options"
    read -p "Type theme name: " selected_name
fi

[ -z "$selected_name" ] && exit 0

selected_file=""
for t in "${themes[@]}"; do
    name=$(grep "@name:" "$t" | cut -d':' -f2 | sed 's/^ //')
    [ -z "$name" ] && name=$(basename "$t" .css)
    if [ "$name" = "$selected_name" ]; then
        selected_file="$t"
        break
    fi
done

if [ -z "$selected_file" ]; then
    error "Theme not found."
    exit 1
fi

log "Applying theme: $selected_name"

# --- 1. Apply Waybar Style ---
rm -f "$WAYBAR_STYLE"
ln -s "$selected_file" "$WAYBAR_STYLE"

# --- 2. Extract Variables ---
get_var() {
    grep "@$1:" "$selected_file" | cut -d':' -f2- | sed 's/^ //'
}

# Hyprland
h_active_border=$(get_var "hypr-active-border")
h_inactive_border=$(get_var "hypr-inactive-border")
h_gaps_in=$(get_var "hypr-gaps-in")
h_gaps_out=$(get_var "hypr-gaps-out")
h_rounding=$(get_var "hypr-rounding")
h_active_opacity=$(get_var "hypr-active-opacity")
h_inactive_opacity=$(get_var "hypr-inactive-opacity")

# Wofi
w_bg=$(get_var "wofi-bg")
w_border=$(get_var "wofi-border")
w_text=$(get_var "wofi-text")
w_accent=$(get_var "wofi-accent")

# Mako
m_bg=$(get_var "mako-bg")
m_text=$(get_var "mako-text")
m_border=$(get_var "mako-border")
m_rounding=$(get_var "mako-rounding")

# --- 3. Patch Configs ---

# Hyprland
sed -i "s/.*@theme:gaps_in.*/    gaps_in = $h_gaps_in # @theme:gaps_in/" "$HYPR_CONF"
sed -i "s/.*@theme:gaps_out.*/    gaps_out = $h_gaps_out # @theme:gaps_out/" "$HYPR_CONF"
sed -i "s/.*@theme:active_border.*/    col.active_border = $h_active_border # @theme:active_border/" "$HYPR_CONF"
sed -i "s/.*@theme:inactive_border.*/    col.inactive_border = $h_inactive_border # @theme:inactive_border/" "$HYPR_CONF"
sed -i "s/.*@theme:rounding.*/    rounding = $h_rounding # @theme:rounding/" "$HYPR_CONF"
sed -i "s/.*@theme:active_opacity.*/    active_opacity = $h_active_opacity # @theme:active_opacity/" "$HYPR_CONF"
sed -i "s/.*@theme:inactive_opacity.*/    inactive_opacity = $h_inactive_opacity # @theme:inactive_opacity/" "$HYPR_CONF"

# Wofi (Note: using /* */ comments for CSS)
sed -i "s|.*@theme:wofi_bg.*|    background: $w_bg; /* @theme:wofi_bg */|g" "$WOFI_STYLE"
sed -i "s|.*@theme:wofi_border.*|    border: 1px solid $w_border; /* @theme:wofi_border */|g" "$WOFI_STYLE"
sed -i "s|.*@theme:wofi_text.*|    color: $w_text; /* @theme:wofi_text */|g" "$WOFI_STYLE"
sed -i "s|.*@theme:wofi_accent.*|    background-color: $w_accent; /* @theme:wofi_accent */|g" "$WOFI_STYLE"

# Mako
sed -i "s/.*@theme:mako_bg.*/background-color=$m_bg # @theme:mako_bg/" "$MAKO_CONF"
sed -i "s/.*@theme:mako_text.*/text-color=$m_text # @theme:mako_text/" "$MAKO_CONF"
sed -i "s/.*@theme:mako_border.*/border-color=$m_border # @theme:mako_border/" "$MAKO_CONF"
sed -i "s/.*@theme:mako_rounding.*/border-radius=$m_rounding # @theme:mako_rounding/" "$MAKO_CONF"

# --- 3.5 Apply Widget Themes ---
log "Updating widgets..."
while read -r line; do
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
                ln -s "$source_theme" "$widget_dir/theme.css"
            fi
        fi
    fi
done < <(grep "@widget-" "$selected_file")

# --- 4. Icon Generation (Dynamic Taskbar) ---
accent_color=$(grep "@mako-border" "$selected_file" | cut -d':' -f2 | tr -d '[:space:]')
if [ -z "$accent_color" ]; then
    accent_color="#ff8fbd" # Default pink
fi

if [ -f "$REPO_DIR/scripts/icon-gen.sh" ]; then
    log "Generating themed icons for color: $accent_color"
    bash "$REPO_DIR/scripts/icon-gen.sh" "$accent_color"
fi

# --- 5. Sync to ~/.config ---
mkdir -p "$HOME/.config/waybar" "$HOME/.config/hypr" "$HOME/.config/wofi" "$HOME/.config/mako"

# Helper to copy only if source and dest are different
safe_cp() {
    src="$1"
    dest="$2"
    [ -f "$src" ] || return 0
    if [ "$(realpath -m "$src")" != "$(realpath -m "$dest")" ]; then
        cp "$src" "$dest"
    fi
}

safe_cp "$WAYBAR_STYLE" "$HOME/.config/waybar/style.css"
safe_cp "$HYPR_CONF" "$HOME/.config/hypr/hyprland.conf"
safe_cp "$WOFI_STYLE" "$HOME/.config/wofi/style.css"
safe_cp "$MAKO_CONF" "$HOME/.config/mako/config"

# Sync widgets
if [ -d "$REPO_DIR/widgets" ]; then
    mkdir -p "$HOME/.config/waybar/widgets"
    # Only copy if we are not already in the config directory
    if [ "$(realpath -m "$REPO_DIR/widgets")" != "$(realpath -m "$HOME/.config/waybar/widgets")" ]; then
        cp -a "$REPO_DIR/widgets/." "$HOME/.config/waybar/widgets/"
    fi
fi

# --- 5. Refresh ---
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

if command -v makoctl >/dev/null 2>&1; then
    makoctl reload >/dev/null 2>&1 || true
fi

if [ -x "$REPO_DIR/scripts/restart-waybar.sh" ]; then
    nohup "$REPO_DIR/scripts/restart-waybar.sh" >/dev/null 2>&1 &
else
    pkill waybar || true
    sleep 0.5
    nohup waybar >/dev/null 2>&1 &
fi

log "Global theme applied successfully!"
