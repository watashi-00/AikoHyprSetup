#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_MIN="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_MIN="$SCRIPT_DIR_MIN/lib/utils.sh"

if [ -f "$LIB_UTILS_MIN" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_MIN"
fi

if ! have hyprctl || ! have jq; then
    exit 1
fi

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
