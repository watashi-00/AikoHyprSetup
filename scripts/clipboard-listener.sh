#!/usr/bin/env bash

if ! command -v wl-paste >/dev/null 2>&1 || ! command -v cliphist >/dev/null 2>&1; then
    exit 0
fi

# Store text and images
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store
