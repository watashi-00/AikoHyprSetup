#!/bin/bash
MODE=$1
ADDR=$2

if [[ "$MODE" == "minimize" ]]; then
    if [ -z "$ADDR" ]; then
        ADDR=$(hyprctl activewindow -j | jq -r ".address")
    fi
    if [[ "$ADDR" != "null" && -n "$ADDR" ]]; then
        hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDR"
    fi

elif [[ "$MODE" == "restore" ]]; then
    # Find the last window added to the special workspace
    ADDR=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:minimized") | .address' | tail -n 1)
    
    if [[ "$ADDR" != "null" && -n "$ADDR" ]]; then
        CURRENT_WS=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.id')
        hyprctl dispatch movetoworkspace "$CURRENT_WS,address:$ADDR"
        
        sleep 0.1
        
        # Force tiling mode
        IS_FLOATING=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$ADDR\") | .floating")
        if [[ "$IS_FLOATING" == "true" ]]; then
            hyprctl dispatch togglefloating "address:$ADDR"
        fi
        
        hyprctl dispatch focuswindow "address:$ADDR"
    fi

else
    # Toggle behavior for taskbar clicks (compatibility)
    if [ -z "$ADDR" ]; then
        ADDR=$(hyprctl activewindow -j | jq -r ".address")
    fi
    
    WORKSPACE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$ADDR\") | .workspace.name")
    
    if [[ "$WORKSPACE" == "special:minimized" ]]; then
        $0 restore "$ADDR"
    else
        $0 minimize "$ADDR"
    fi
fi
