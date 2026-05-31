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
    local index key

    _menu_clear

    # Se existir uma função de header definida no script principal, chama ela
    if declare -f print_header > /dev/null; then
        print_header
    fi

    for index in "${!order_ref[@]}"; do
        key="${order_ref[$index]}"
        printf "  ${CYAN}${BOLD}%d)${NC} %s\n" "$((index + 1))" "${labels_ref[$key]}"
    done

    printf "\n${WHITE}Escolha uma opção e pressione [ENTER] (ou 'q' para sair): ${NC}"
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

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#order_ref[@]}" ]; then
            key="${order_ref[$((choice - 1))]}"
            action="${actions_ref[$key]}"
            
            if [ -n "$action" ] && declare -f "$action" > /dev/null; then
                _menu_clear
                "$action"
                action_status="$?"

                if [ "$action_status" -eq 130 ]; then
                    return 0
                fi
                
                printf "\n${WHITE}Pressione qualquer tecla para voltar ao menu...${NC}"
                read -rsn1
            fi
        else
            printf "${RED}Opção inválida!${NC}\n"
            sleep 1
        fi
    done
}
