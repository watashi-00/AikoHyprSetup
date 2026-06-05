#!/usr/bin/env bash

# search.sh - Advanced Wofi Search Utility for AikoHyprSetup
# Supports search prefixes (g: Google, y: YouTube, w: Wiki, f: Find File)

SCRIPT_DIR_SEARCH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_SEARCH="$SCRIPT_DIR_SEARCH/lib/utils.sh"

if [ -f "$LIB_UTILS_SEARCH" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_SEARCH"
else
    AIKO_ROOT="$HOME/.config/waybar"
fi

WOFI_CONF="$HOME/.config/wofi/config"
WOFI_STYLE="$HOME/.config/wofi/style.css"
[ ! -f "$WOFI_CONF" ] && WOFI_CONF="$AIKO_ROOT/configs/wofi/config"
[ ! -f "$WOFI_STYLE" ] && WOFI_STYLE="$AIKO_ROOT/configs/wofi/style.css"

# If wofi is already running, toggle it off
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

# Run the search input prompt
QUERY=$(wofi --dmenu --prompt "Aiko Search (g: Google | y: YouTube | w: Wiki | f: File)..." --conf "$WOFI_CONF" --style "$WOFI_STYLE")

[ -z "$QUERY" ] && exit 0

# Parse prefix and query
if [[ "$QUERY" =~ ^g:[[:space:]]*(.*)$ ]] || [[ "$QUERY" =~ ^g[[:space:]]+(.*)$ ]]; then
    # Google Search
    TERM="${BASH_REMATCH[1]}"
    xdg-open "https://www.google.com/search?q=${TERM// /+}"
elif [[ "$QUERY" =~ ^y:[[:space:]]*(.*)$ ]] || [[ "$QUERY" =~ ^y[[:space:]]+(.*)$ ]]; then
    # YouTube Search
    TERM="${BASH_REMATCH[1]}"
    xdg-open "https://www.youtube.com/results?search_query=${TERM// /+}"
elif [[ "$QUERY" =~ ^w:[[:space:]]*(.*)$ ]] || [[ "$QUERY" =~ ^w[[:space:]]+(.*)$ ]]; then
    # Wikipedia Search
    TERM="${BASH_REMATCH[1]}"
    xdg-open "https://en.wikipedia.org/wiki/Special:Search?search=${TERM// /+}"
elif [[ "$QUERY" =~ ^f:[[:space:]]*(.*)$ ]] || [[ "$QUERY" =~ ^f[[:space:]]+(.*)$ ]]; then
    # File Search
    TERM="${BASH_REMATCH[1]}"
    # Find matching files in user's home (excluding common hidden/cache folders to be fast)
    FILES=$(find "$HOME" -not -path '*/.*' -not -path '*Cache*' -iname "*$TERM*" -type f 2>/dev/null | head -n 30)
    
    if [ -z "$FILES" ]; then
        notify-send "Aiko Search" "No files found matching '$TERM'" -i system-search
        exit 0
    fi
    
    # Let user select which file to open
    SELECTED_FILE=$(echo "$FILES" | wofi --dmenu --prompt "Select file to open..." --conf "$WOFI_CONF" --style "$WOFI_STYLE")
    [ -n "$SELECTED_FILE" ] && xdg-open "$SELECTED_FILE"
else
    # Default behavior:
    # 1. If it's a command/app in PATH, run it
    if command -v "$QUERY" >/dev/null 2>&1; then
        exec "$QUERY" &
    else
        # 2. Otherwise search on Google
        xdg-open "https://www.google.com/search?q=${QUERY// /+}"
    fi
fi
