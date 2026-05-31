#!/usr/bin/env bash
# Output a fontawesome play/pause symbol (fallback to text) without quoting issues
if playerctl status 2> /dev/null | grep -q "Playing"; then
    echo "\uf04c"
else
    echo "\uf04b"
fi
