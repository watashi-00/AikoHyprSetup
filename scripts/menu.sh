#!/bin/bash

# Return from the current menu. Useful for submenu "Back" actions.
menu_back() {
    return 130
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

    # If a header function exists in the main script, call it
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

    while true; do
        _menu_render "$labels_name" "$order_name"
        
        read -r choice
        
        if [[ "$choice" =~ ^[Qq]$ ]]; then
            return 0
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

                if [ "$action_status" -eq 130 ]; then
                    return 0
                fi
                
                # Check if it was an exit/quit action
                if [ "$action_status" -eq 127 ]; then
                    exit 0
                fi

                printf "\n${WHITE}Press any key to return to the menu...${NC}"
                read -rsn1
            fi
        else
            printf "${RED}Invalid option!${NC}\n"
            sleep 1
        fi
    done
}

# Usability utility for Y/N prompts
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local response

    while true; do
        if [[ "$default" == "y" ]]; then
            printf "%b %s [Y/n]: %b" "${CYAN}${BOLD}" "$prompt" "${NC}"
        else
            printf "%b %s [y/N]: %b" "${CYAN}${BOLD}" "$prompt" "${NC}"
        fi
        
        read -r response
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        
        if [[ -z "$response" ]]; then
            response="$default"
        fi

        case "$response" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) printf "${RED}Please enter 'y' or 'n'.${NC}\n" ;;
        esac
    done
}
