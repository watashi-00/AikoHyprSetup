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

# Ensure we have a valid address for minimize/toggle
get_active_address() {
    hyprctl activewindow -j | jq -r ".address // empty"
}

# Ensure we have a valid current workspace name
get_current_workspace() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .activeWorkspace.name'
}

if [[ "$MODE" == "minimize" ]]; then
    if [ -z "$ADDR" ]; then
        ADDR=$(get_active_address)
    fi
    
    if [[ -n "$ADDR" && "$ADDR" != "null" ]]; then
        hyprctl dispatch movetoworkspacesilent "special:minimized,address:$ADDR"
    fi

elif [[ "$MODE" == "restore" ]]; then
    # Find the last window added to the special workspace
    # We use a more flexible select to catch any variant of the special workspace
    ADDR=$(hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:minimized") | .address' | tail -n 1)
    
    if [[ -n "$ADDR" && "$ADDR" != "null" ]]; then
        CURRENT_WS=$(get_current_workspace)
        
        # If we are currently in a special workspace, move to workspace 1 as fallback
        if [[ "$CURRENT_WS" == special:* ]]; then
            CURRENT_WS="1"
        fi

        hyprctl dispatch movetoworkspace "$CURRENT_WS,address:$ADDR"
        
        # Give Hyprland a moment to process the move
        sleep 0.1
        
        # Focus the restored window
        hyprctl dispatch focuswindow "address:$ADDR"
    fi

else
    # Toggle behavior
    if [ -z "$ADDR" ]; then
        ADDR=$(get_active_address)
    fi
    
    if [[ -n "$ADDR" && "$ADDR" != "null" ]]; then
        WORKSPACE=$(hyprctl clients -j | jq -r ".[] | select(.address == \"$ADDR\") | .workspace.name")
        
        if [[ "$WORKSPACE" == "special:minimized" ]]; then
            # Use this script to restore
            bash "$0" restore "$ADDR"
        else
            # Use this script to minimize
            bash "$0" minimize "$ADDR"
        fi
    else
        # If no active window, try to restore the last minimized one
        bash "$0" restore
    fi
fi
