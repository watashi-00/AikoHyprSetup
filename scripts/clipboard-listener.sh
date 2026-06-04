#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_CLIP_L="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_CLIP_L="$SCRIPT_DIR_CLIP_L/lib/utils.sh"

if [ -f "$LIB_UTILS_CLIP_L" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_CLIP_L"
fi

if ! have wl-paste || ! have cliphist; then
    exit 0
fi

# Store text and images
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store
