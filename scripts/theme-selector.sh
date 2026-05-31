#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$REPO_DIR/themes"
WAYBAR_STYLE="$REPO_DIR/waybar/style.css"
HYPR_CONF="$REPO_DIR/configs/hypr/hyprland.conf"
INSTALLED_HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

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

# Build menu labels
options=""
for t in "${themes[@]}"; do
    name=$(grep "@name:" "$t" | cut -d':' -f2 | sed 's/^ //')
    [ -z "$name" ] && name=$(basename "$t" .css)
    options+="$name\n"
done

# Use wofi if available
if command -v wofi >/dev/null 2>&1; then
    selected_name=$(echo -e "$options" | wofi --dmenu --prompt "Select Theme" --width 300 --height 350)
else
    echo "Available themes:"
    echo -e "$options"
    read -p "Type theme name: " selected_name
fi

[ -z "$selected_name" ] && exit 0

# Find the file matching selected name
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

# --- Apply Waybar Style ---
rm -f "$WAYBAR_STYLE"
ln -s "$selected_file" "$WAYBAR_STYLE"

# --- Extract & Apply Hyprland Variables ---
get_var() {
    grep "@hypr-$1:" "$selected_file" | cut -d':' -f2- | sed 's/^ //'
}

gaps_in=$(get_var "gaps-in")
gaps_out=$(get_var "gaps-out")
active_border=$(get_var "active-border")
inactive_border=$(get_var "inactive-border")
rounding=$(get_var "rounding")
active_opacity=$(get_var "active-opacity")
inactive_opacity=$(get_var "inactive-opacity")

# Patch local config using full-line replacement for safety
sed -i "s/.*@theme:gaps_in.*/    gaps_in = $gaps_in # @theme:gaps_in/" "$HYPR_CONF"
sed -i "s/.*@theme:gaps_out.*/    gaps_out = $gaps_out # @theme:gaps_out/" "$HYPR_CONF"
sed -i "s/.*@theme:active_border.*/    col.active_border = $active_border # @theme:active_border/" "$HYPR_CONF"
sed -i "s/.*@theme:inactive_border.*/    col.inactive_border = $inactive_border # @theme:inactive_border/" "$HYPR_CONF"
sed -i "s/.*@theme:rounding.*/    rounding = $rounding # @theme:rounding/" "$HYPR_CONF"
sed -i "s/.*@theme:active_opacity.*/    active_opacity = $active_opacity # @theme:active_opacity/" "$HYPR_CONF"
sed -i "s/.*@theme:inactive_opacity.*/    inactive_opacity = $inactive_opacity # @theme:inactive_opacity/" "$HYPR_CONF"

# --- Sync to ~/.config ---
mkdir -p "$HOME/.config/waybar"
mkdir -p "$HOME/.config/hypr"

cp "$WAYBAR_STYLE" "$HOME/.config/waybar/style.css"
cp "$HYPR_CONF" "$INSTALLED_HYPR_CONF"

# --- Refresh Environment ---
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

if [ -x "$REPO_DIR/scripts/restart-waybar.sh" ]; then
    nohup "$REPO_DIR/scripts/restart-waybar.sh" >/dev/null 2>&1 &
else
    pkill waybar || true
    sleep 0.5
    nohup waybar >/dev/null 2>&1 &
fi

log "Theme applied successfully!"
