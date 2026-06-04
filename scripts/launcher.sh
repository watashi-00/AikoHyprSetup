#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_LAUNCHER="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_LAUNCHER="$SCRIPT_DIR_LAUNCHER/lib/utils.sh"

if [ -f "$LIB_UTILS_LAUNCHER" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_LAUNCHER"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_CONFIGS="$AIKO_ROOT/configs"
fi

# Wofi launcher with custom style
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

# Standard config paths
WOFI_CONF="$HOME/.config/wofi/config"
WOFI_STYLE="$HOME/.config/wofi/style.css"

# Fallbacks to Aiko-specific configs if standard ones are missing
[ ! -f "$WOFI_CONF" ] && WOFI_CONF="$AIKO_CONFIGS/wofi/config"
[ ! -f "$WOFI_STYLE" ] && WOFI_STYLE="$AIKO_CONFIGS/wofi/style.css"

wofi --show drun --prompt "Search..." --conf "$WOFI_CONF" --style "$WOFI_STYLE"
