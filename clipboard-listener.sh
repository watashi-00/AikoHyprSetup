#!/usr/bin/env bash
set -euo pipefail

if ! command -v wl-paste >/dev/null 2>&1 || ! command -v cliphist >/dev/null 2>&1; then
    exit 0
fi

wl-paste --watch cliphist store
