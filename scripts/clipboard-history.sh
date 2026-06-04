#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_CLIP="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_CLIP="$SCRIPT_DIR_CLIP/lib/utils.sh"

if [ -f "$LIB_UTILS_CLIP" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_CLIP"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_CONFIGS="$AIKO_ROOT/configs"
fi

# Clipboard history using cliphist and wofi
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

WOFI_STYLE="$HOME/.config/wofi/style.css"
[ ! -f "$WOFI_STYLE" ] && WOFI_STYLE="$AIKO_CONFIGS/wofi/style.css"

if have cliphist && have wofi && have wl-copy; then
    cliphist list | wofi --dmenu --prompt "Clipboard" --style "$WOFI_STYLE" | cliphist decode | wl-copy
fi
