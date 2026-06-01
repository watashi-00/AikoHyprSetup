#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CURRENT_THEME="pink-anime"
if [ -L "$HOME/.config/waybar/style.css" ]; then
    THEME_PATH=$(readlink "$HOME/.config/waybar/style.css")
    if [[ "$THEME_PATH" == *"cyber-blue"* ]]; then
        CURRENT_THEME="cyber-blue"
    fi
fi

cp "$SCRIPT_DIR/themes/$CURRENT_THEME.css" "$SCRIPT_DIR/theme.css"

python3 "$SCRIPT_DIR/aiko-sys.py"
