#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_ART="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_ART="$SCRIPT_DIR_ART/lib/utils.sh"

if [ -f "$LIB_UTILS_ART" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_ART"
fi

if ! have playerctl; then
    exit 0
fi

# Prefer Spotify specifically, then fallback to any running player
artUrl=$(playerctl --player=spotify,spotifyd metadata mpris:artUrl 2> /dev/null || playerctl metadata mpris:artUrl 2> /dev/null)

if [ -z "$artUrl" ]; then
    echo ""
    exit 0
fi

# Generate unique filename based on URL hash to bypass Waybar's image caching
url_hash=$(echo -n "$artUrl" | md5sum | cut -d' ' -f1)
filename="/tmp/spotify_cover_${url_hash}.png"

if [ -f "$filename" ]; then
    echo "$filename"
    exit 0
fi

# Clean up any old covers
find /tmp -name "spotify_cover_*.png" -delete 2>/dev/null

# Support file:// paths and http(s) URLs
if [[ "$artUrl" == file://* ]]; then
    filepath="${artUrl#file://}"
    if [ -f "$filepath" ]; then
        cp "$filepath" "$filename" 2> /dev/null || true
        echo "$filename"
        exit 0
    fi
fi

if have curl; then
    curl -s -L "$artUrl" -o "$filename" || true
fi

if [ -f "$filename" ]; then
    echo "$filename"
else
    echo ""
fi
