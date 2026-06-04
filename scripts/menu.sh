#!/usr/bin/env bash

# menu.sh - Modular Menu System for AikoHyprSetup
# Integrated with utils.sh for consistent styling and behavior.

# Resolve real path to locate utility library
SCRIPT_DIR_MENU="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_MENU="$SCRIPT_DIR_MENU/lib/utils.sh"

if [ -f "$LIB_UTILS_MENU" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_MENU"
fi

# Return from the current menu. Useful for submenu "Back" actions.
menu_back() {
    return "$AIKO_EXIT_MENU_BACK"
}

_menu_build_default_order() {
    local labels_name="$1"
    local -n labels_ref="$labels_name"
    local key

    for key in "${!labels_ref[@]}"; do
        printf '%s\n' "$key"
    done | sort -n
}

_menu_clear() {
    if [ -t 1 ]; then
        clear
    fi
}

_menu_render() {
    local labels_name="$1"
    local order_name="$2"
    local -n labels_ref="$labels_name"
    local -n order_ref="$order_name"
    local index key item_num=1

    _menu_clear

    # If a header function exists in the calling script, call it
    if declare -f print_header > /dev/null; then
        print_header
    fi

    for index in "${!order_ref[@]}"; do
        key="${order_ref[$index]}"
        if [ "$key" = "0" ]; then continue; fi
        printf "  ${CYAN}${BOLD}%d)${NC} %s\n" "$item_num" "${labels_ref[$key]}"
        item_num=$((item_num + 1))
    done

    # Always show 0 at the end if it exists
    if [ -n "${labels_ref[0]}" ]; then
        printf "  ${CYAN}${BOLD}0)${NC} %s\n" "${labels_ref[0]}"
    fi

    printf "\n${WHITE}Choose an option and press [ENTER] (or 'q' to exit): ${NC}"
}

menu() {
    local labels_name="$2"
    local actions_name="$3"
    local order_name="$4"

    local -n labels_ref="$labels_name"
    local -n actions_ref="$actions_name"
    local -n order_ref="$order_name"
    
    local choice key action action_status

    # Standardize terminal state
    aiko_cleanup_term

    while true; do
        _menu_render "$labels_name" "$order_name"
        
        # Ensure focus/paste tracking stays off
        aiko_cleanup_term
        read -r choice
        
        if [[ "$choice" =~ ^[Qq]$ ]]; then
            return 2 # Navigation code for silent return
        fi

        key=""
        if [[ "$choice" == "0" ]] && [ -n "${labels_ref[0]}" ]; then
            key="0"
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ]; then
            # Map choice to non-zero keys
            local current=1
            for k in "${order_ref[@]}"; do
                if [ "$k" = "0" ]; then continue; fi
                if [ "$current" -eq "$choice" ]; then
                    key="$k"
                    break
                fi
                current=$((current + 1))
            done
        fi

        if [ -n "$key" ]; then
            action="${actions_ref[$key]}"
            
            if [ -n "$action" ] && declare -f "$action" > /dev/null; then
                _menu_clear
                "$action"
                action_status="$?"

                # 130 means "Return from this menu loop"
                if [ "$action_status" -eq "$AIKO_EXIT_MENU_BACK" ]; then
                    return "$AIKO_EXIT_MENU_CONTINUE" # Standard code for exiting a menu level silently
                fi
                
                # 2 means "Action complete, return to loop silently (Submenu just finished)"
                if [ "$action_status" -eq "$AIKO_EXIT_MENU_CONTINUE" ]; then
                    continue
                fi

                # Check if it was an exit/quit action
                if [ "$action_status" -eq 127 ]; then
                    exit 0
                fi

                # Standard prompt for non-navigation actions
                printf "\n${WHITE}Press any key to return to the menu...${NC}"
                read -rsn1
            fi
        else
            printf "${RED}Invalid option!${NC}\n"
            sleep 1
        fi
    done
}
