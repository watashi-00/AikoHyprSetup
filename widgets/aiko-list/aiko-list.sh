#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Define the local theme path based on the current system theme
# Assuming the theme is linked at ~/.config/waybar/theme.css or similar
# For Aiko widgets, we usually look for a specific CSS file in the widget's theme folder

# Check for Waybar theme to decide which widget theme to use
CURRENT_THEME="pink-anime"
if [ -L "$HOME/.config/waybar/style.css" ]; then
    THEME_PATH=$(readlink "$HOME/.config/waybar/style.css")
    if [[ "$THEME_PATH" == *"cyber-blue"* ]]; then
        CURRENT_THEME="cyber-blue"
    fi
fi

# Copy the appropriate theme file to a generic name for the python script to load
cp "$SCRIPT_DIR/themes/$CURRENT_THEME.css" "$SCRIPT_DIR/theme.css"

# Run the python script
python3 "$SCRIPT_DIR/aiko-list.py"
