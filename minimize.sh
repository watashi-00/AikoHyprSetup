#!/bin/bash
ADDR=$1
if [ -z "$ADDR" ]; then
    ADDR=$(hyprctl activewindow -j | jq -r ".address")
fi

# Get window info
WINDOW_INFO=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$ADDR\")")
WORKSPACE=$(echo "$WINDOW_INFO" | jq -r ".workspace.name")

if [[ "$WORKSPACE" == "special:minimized" ]]; then
    # Moving back to the active workspace
    CURRENT_WS=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
    hyprctl dispatch movetoworkspace "$CURRENT_WS,address:$ADDR"
    
    # Give it a moment to settle
    sleep 0.1
    
    # If the window is still floating, toggle it to tiling mode
    IS_FLOATING=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$ADDR\") | .floating")
    if [[ "$IS_FLOATING" == "true" ]]; then
        hyprctl dispatch togglefloating "address:$ADDR"
    fi
    
    # Focus the restored window
    hyprctl dispatch focuswindow "address:$ADDR"
else
    # Minimize: move to the special workspace
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDR"
fi
