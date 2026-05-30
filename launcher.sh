#!/usr/bin/env bash

# Wofi launcher with custom style
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

wofi --show drun --prompt "Buscar..." --conf ~/.config/waybar/wofi.conf --style ~/.config/waybar/wofi.css
