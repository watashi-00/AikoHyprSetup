#!/usr/bin/env bash

# AikoHyprSetup V2 - Health & Maintenance
# Handles post-install checks, applying changes, and cleanup.

post_install_checks() {
    local required_bins=(
        hyprland waybar wofi mako hyprpaper kitty jq playerctl pactl wpctl 
        wl-copy wl-paste cliphist notify-send grim slurp curl
        hyprpicker swappy nm-applet bluetoothctl pavucontrol cava zenity 
        gthumb magick
    )
    local missing_required=()
    local bin

    printf "\n${BOLD}--- Binary Check ---${NC}\n"
    for bin in "${required_bins[@]}"; do
        if have "$bin"; then
            printf "  ${GREEN}%s${NC} %-15s ${GREEN}[OK]${NC}\n" "$ICON_CHECK" "$bin"
        else
            printf "  ${RED}%s${NC} %-15s ${RED}[MISSING]${NC}\n" "$ICON_ERROR" "$bin"
            missing_required+=("$bin")
        fi
    done

    if [ "${#missing_required[@]}" -gt 0 ]; then
        warn "Critical binaries still missing: ${missing_required[*]}"
    fi
}

apply_changes() {
    log "${MAGENTA}Applying configurations...${NC}"

    local waybar_dest="$HOME/.config/waybar"
    local local_restart="$AIKO_SCRIPTS/restart-waybar.sh"

    if [ -f "$local_restart" ]; then
        log "Using source restart script for immediate application..."
        run bash "$local_restart"
    elif [ -x "$waybar_dest/restart-waybar.sh" ]; then
        run "$waybar_dest/restart-waybar.sh"
    elif have waybar; then
        pkill waybar 2>/dev/null || true
        waybar --config "$waybar_dest/config-left.jsonc" --style "$waybar_dest/style.css" &
        waybar --config "$waybar_dest/config.jsonc" --style "$waybar_dest/style.css" &
        waybar --config "$waybar_dest/config-bottom.jsonc" --style "$waybar_dest/style.css" &
    else
        warn "waybar not found."
    fi

    if have hyprctl; then
        hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed. Execute manually in Hyprland."
    fi
}

cleanup_generated_backups() {
    local search_dirs=(
        "$HOME/.config/waybar"
        "$HOME/.config/hypr"
        "$HOME/.config/wofi"
        "$HOME/.config/mako"
        "$HOME/.config/kitty"
        "$HOME/.config/fastfetch"
        "$HOME/.local/share/applications"
    )
    local -a backups=()
    local dir

    log "Scanning for generated backup files..."
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        while IFS= read -r -d '' item; do
            backups+=("$item")
        done < <(find "$dir" \( -type f -o -type l -o -type d \) -name '*.bak-*' -print0)
    done

    if [ "${#backups[@]}" -eq 0 ]; then
        success "No generated backup files found."
        return 0
    fi

    printf "\n${BOLD}${YELLOW}Found %d backup item(s):${NC}\n" "${#backups[@]}"
    printf '%s\n' "${backups[@]}"
    echo

    if ! confirm "Delete all generated backup files listed above?" "n"; then
        log "Cleanup cancelled."
        return 0
    fi

    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        find "$dir" \( -type f -o -type l -o -type d \) -name '*.bak-*' -exec rm -rf -- {} +
    done

    success "Generated backup files removed."
    return 0
}

prompt_apply() {
    if confirm "Apply changes and restart Waybar now?"; then
        apply_changes
    fi
}

action_self_test() {
    if [ -f "$AIKO_SCRIPTS/test.sh" ]; then
        bash "$AIKO_SCRIPTS/test.sh"
    else
        error "Self-test script not found."
        return 1
    fi
}
