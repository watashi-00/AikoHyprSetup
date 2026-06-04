#!/usr/bin/env bash
set -euo pipefail

# --- Initial Settings ---
REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SOURCE_DIR_LOCAL="$(cd "$(dirname "$REAL_PATH")" && pwd)"

# --- Load Central Utility Library ---
LIB_UTILS="$SOURCE_DIR_LOCAL/scripts/lib/utils.sh"
[ ! -f "$LIB_UTILS" ] && LIB_UTILS="$SOURCE_DIR_LOCAL/lib/utils.sh"

if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="install"
aiko_init_term

REPO_ISSUES="https://github.com/watashi-00/AikoHyprSetup/issues"

# Logic for source files location (repo vs installed)
if [ -f "$AIKO_ROOT/waybar/config.jsonc" ]; then
    AIKO_SOURCE_WAYBAR="$AIKO_ROOT/waybar"
else
    AIKO_SOURCE_WAYBAR="$AIKO_ROOT"
fi

INSTALL_PACKAGES=1
INSTALL_HYPR=1
FORCE=0
DRY_RUN=0

# --- Load Modular Menu ---
if [ -f "$AIKO_SCRIPTS/menu.sh" ]; then
    # shellcheck disable=SC1091
    source "$AIKO_SCRIPTS/menu.sh"
elif [ -f "$AIKO_ROOT/menu.sh" ]; then
    source "$AIKO_ROOT/menu.sh"
else
    die "menu.sh not found in $AIKO_SCRIPTS or $AIKO_ROOT"
fi

# --- Summary Variables ---
INSTALLED_PKGS=0
COPIED_FILES=0
BACKUPS_CREATED=0

# --- Internal Logic ---

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "${YELLOW}[dry-run]${NC} %s\n" "$*"
    else
        "$@"
    fi
}

sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

validate_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        log "Privileged access required. Please enter your password:"
        sudo -v || die "Sudo authentication failed."
    fi
}

pm_detect() {
    if have pacman; then echo pacman; return; fi
    if have apt-get; then echo apt; return; fi
    if have dnf; then echo dnf; return; fi
    if have zypper; then echo zypper; return; fi
    if have apk; then echo apk; return; fi
    echo unknown
}

packages_for_pm() {
    case "$1" in
        pacman)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify network-manager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez ttf-font-awesome \
                ttf-jetbrains-mono-nerd polkit-kde-agent zenity gthumb imagemagick \
                python-gobject socat
            ;;
        apt)
            printf '%s\n' \
                hyprland waybar wofi mako-notifier hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-bin network-manager-gnome grim slurp curl \
                hyprpicker swappy xdg-utils bluez fonts-font-awesome \
                fonts-jetbrains-mono polkit-kde-agent-1 zenity gthumb imagemagick \
                python3-gi socat
            ;;
        dnf)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde zenity gthumb ImageMagick \
                python3-gobject socat
            ;;
        zypper)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-tools NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde-agent-6 zenity gthumb ImageMagick \
                python3-gobject socat
            ;;
        apk)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify network-manager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                ttf-jetbrains-mono polkit-kde-agent zenity gthumb imagemagick \
                py3-gobject3 socat
            ;;
    esac
}

install_one_package() {
    pm="$1"
    pkg="$2"

    case "$pm" in
        pacman) sudo_cmd pacman -S --needed --noconfirm "$pkg" ;;
        apt) sudo_cmd apt-get install -y "$pkg" ;;
        dnf) sudo_cmd dnf install -y "$pkg" ;;
        zypper) sudo_cmd zypper --non-interactive install --no-recommends "$pkg" ;;
        apk) sudo_cmd apk add "$pkg" ;;
        *) return 1 ;;
    esac
}

install_packages() {
    pm="$(pm_detect)"
    if [ "$pm" = unknown ]; then
        warn "Package manager not supported. Skipping dependencies."
        return 0
    fi

    validate_sudo

    log "Detected package manager: ${BOLD}$pm${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        packages_for_pm "$pm" | sed "s/^/${YELLOW}[dry-run]${NC} package: /"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ] && ! have sudo; then
        warn "sudo not found. Skipping package installation."
        return 0
    fi

    case "$pm" in
        apt) sudo_cmd apt-get update ;;
        zypper) sudo_cmd zypper --non-interactive refresh ;;
        apk) sudo_cmd apk update ;;
    esac

    missing=""
    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        printf "  ${CYAN}%s${NC} Checking/Installing: ${WHITE}%s${NC}..." "$ICON_PACKAGE" "$pkg"
        if install_one_package "$pm" "$pkg" >/dev/null 2>&1; then
            printf " ${GREEN}OK${NC}\n"
            INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
        else
            printf " ${RED}FAILED${NC}\n"
            warn "Could not install '$pkg' via $pm."
            missing="${missing}${pkg} "
        fi
    done < <(packages_for_pm "$pm")

    if [ -n "$missing" ]; then
        warn "Pending packages: $missing"
    fi
}

backup_path() {
    target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        stamp="$(date +%Y%m%d-%H%M%S)"
        backup="${target}.bak-${stamp}"
        log "Backup: $(basename "$target") -> $(basename "$backup")"
        run mv "$target" "$backup"
        BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
    fi
}

copy_file() {
    src="$1"
    dest="$2"

    [ -e "$src" ] || die "Source file not found: $src"
    run mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        src_real="$(realpath -m "$src")"
        dest_real="$(realpath -m "$dest")"
        if [ "$src_real" = "$dest_real" ]; then
            return 0
        fi
        
        # Prevent backups for .desktop files to avoid duplication in launchers
        if [[ "$dest" == *.desktop ]]; then
            log "Updating: ${WHITE}$(basename "$src")${NC}"
            run rm -f "$dest"
        else
            backup_path "$dest"
        fi
    fi

    log "Copying: ${WHITE}$(basename "$src")${NC} -> ${WHITE}$dest${NC}"
    run cp -P "$src" "$dest"
    COPIED_FILES=$((COPIED_FILES + 1))
}

copy_dir_contents() {
    src_dir="$1"
    dest_dir="$2"

    [ -d "$src_dir" ] || return 0
    run mkdir -p "$dest_dir"

    find "$src_dir" -mindepth 1 -maxdepth 1 | while IFS= read -r src; do
        dest="$dest_dir/$(basename "$src")"
        if [ -d "$src" ] && [ ! -L "$src" ]; then
            # If destination exists, backup it before copying new directory
            if [ -d "$dest" ] && [ ! -L "$dest" ]; then
                backup_path "$dest"
            fi
            log "Copying directory: ${WHITE}$(basename "$src")${NC}"
            run cp -a "$src" "$dest"
            COPIED_FILES=$((COPIED_FILES + 1))
        else
            copy_file "$src" "$dest"
        fi
    done
}

patch_installed_paths() {
    file="$1"
    [ -f "$file" ] || return 0
    # Standardize path placeholders to the actual $HOME value
    run sed -i \
        -e "s#@HOME@#$HOME#g" \
        -e "s#/home/watashi#$HOME#g" \
        -e "s#\$HOME#$HOME#g" \
        -e "s#~/.config#$HOME/.config#g" \
        "$file"
}

preserve_hyprland_hw_settings() {
    local hypr_conf="$1"
    local old_conf_content="$2"
    [ -n "$old_conf_content" ] || return 0

    log "Checking for hardware-specific settings to preserve (e.g. from gpu_setup)..."
    
    # Extract monitor lines that are not the generic default
    local monitors
    monitors=$(echo "$old_conf_content" | grep -E '^[[:space:]]*monitor[[:space:]]*=' | grep -v 'preferred, auto, 1' || true)
    
    # Extract environment variables (often GPU related)
    local envs
    envs=$(echo "$old_conf_content" | grep -E '^[[:space:]]*env[[:space:]]*=' || true)

    if [ -n "$monitors" ] || [ -n "$envs" ]; then
        log "Found existing hardware settings. Preserving..."
        
        # Remove the generic monitor line from the new config if we have specific ones
        if [ -n "$monitors" ]; then
            sed -i '/^[[:space:]]*monitor[[:space:]]*=[[:space:]]*,[[:space:]]*preferred,[[:space:]]*auto,[[:space:]]*1/d' "$hypr_conf"
        fi

        {
            echo -e "\n# --- Preserved Hardware Settings (e.g. from gpu_setup) ---"
            [ -n "$monitors" ] && echo "$monitors"
            [ -n "$envs" ] && echo "$envs"
            echo "# ---------------------------------------------------------"
        } >> "$hypr_conf"
    fi
}

install_configs() {
    local waybar_dest="$HOME/.config/waybar"
    local hypr_dest="$HOME/.config/hypr"
    local mako_dest="$HOME/.config/mako"
    local wofi_dest="$HOME/.config/wofi"

    local waybar_files=(
        config.jsonc config-bottom.jsonc config-left.jsonc config-screenshot.jsonc
    )

    log "${MAGENTA}Installing Waybar configs...${NC}"
    for file in "${waybar_files[@]}"; do
        if [ -f "$AIKO_SOURCE_WAYBAR/$file" ]; then
            copy_file "$AIKO_SOURCE_WAYBAR/$file" "$waybar_dest/$file"
            patch_installed_paths "$waybar_dest/$file"
        fi
    done

    log "${MAGENTA}Installing helper scripts...${NC}"
    if [ -d "$AIKO_SCRIPTS" ]; then
        find "$AIKO_SCRIPTS" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.py" \) | while read -r script_src; do
            copy_file "$script_src" "$waybar_dest/$(basename "$script_src")"
            patch_installed_paths "$waybar_dest/$(basename "$script_src")"
        done
    fi

    log "${MAGENTA}Installing Installer itself...${NC}"
    copy_file "$REAL_PATH" "$waybar_dest/install.sh"
    
    if [ -d "$AIKO_SCRIPTS" ]; then
        copy_dir_contents "$AIKO_SCRIPTS" "$waybar_dest/scripts"
        find "$waybar_dest/scripts" -type f -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    log "${MAGENTA}Installing Themes...${NC}"
    if [ -d "$AIKO_THEMES" ]; then
        copy_dir_contents "$AIKO_THEMES" "$waybar_dest/themes"
        find "$waybar_dest/themes" -type f -name "*.css" -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    log "${MAGENTA}Installing Mako and Wofi...${NC}"
    [ -d "$AIKO_CONFIGS/mako" ] && copy_dir_contents "$AIKO_CONFIGS/mako" "$mako_dest"
    [ -d "$AIKO_CONFIGS/wofi" ] && copy_dir_contents "$AIKO_CONFIGS/wofi" "$wofi_dest"
    patch_installed_paths "$mako_dest/config"
    patch_installed_paths "$wofi_dest/config"
    patch_installed_paths "$wofi_dest/style.css"

    log "${MAGENTA}Installing Widgets...${NC}"
    if [ -d "$AIKO_WIDGETS" ]; then
        copy_dir_contents "$AIKO_WIDGETS" "$waybar_dest/widgets"
        find "$waybar_dest/widgets" -type f \( -name "*.sh" -o -name "*.css" -o -name "*.py" \) -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    log "${MAGENTA}Installing Assets...${NC}"
    [ -d "$AIKO_ASSETS" ] && copy_dir_contents "$AIKO_ASSETS" "$waybar_dest/assets"

    log "${MAGENTA}Installing Hyprland config...${NC}"
    if [ "$INSTALL_HYPR" -eq 1 ] && [ -d "$AIKO_CONFIGS/hypr" ]; then
        local hypr_conf="$hypr_dest/hyprland.conf"
        local old_hypr_content=""
        if [ -f "$hypr_conf" ]; then
            old_hypr_content=$(cat "$hypr_conf")
        fi

        copy_dir_contents "$AIKO_CONFIGS/hypr" "$hypr_dest"
        
        if [ -n "$old_hypr_content" ]; then
            preserve_hyprland_hw_settings "$hypr_conf" "$old_hypr_content"
        fi

        patch_installed_paths "$hypr_conf"
        [ -f "$hypr_dest/shortcuts.txt" ] && patch_installed_paths "$hypr_dest/shortcuts.txt"
    fi

    log "${MAGENTA}Installing Desktop Entries...${NC}"
    local app_dir="$HOME/.local/share/applications"
    local icon_dir="$HOME/.local/share/icons"
    mkdir -p "$app_dir" "$icon_dir"
    if [ -d "$AIKO_CONFIGS/applications" ]; then
        copy_dir_contents "$AIKO_CONFIGS/applications" "$app_dir"
        find "$app_dir" -type f -name "aiko-*.desktop" -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g" {} +
    fi

    log "${MAGENTA}Installing Kitty and Fastfetch configs...${NC}"
    mkdir -p "$HOME/.config/kitty" "$HOME/.config/fastfetch"
    [ -d "$AIKO_CONFIGS/kitty" ] && copy_dir_contents "$AIKO_CONFIGS/kitty" "$HOME/.config/kitty"
    [ -d "$AIKO_CONFIGS/fastfetch" ] && copy_dir_contents "$AIKO_CONFIGS/fastfetch" "$HOME/.config/fastfetch"
    patch_installed_paths "$HOME/.config/fastfetch/config.jsonc"

    log "${MAGENTA}Creating default theme links...${NC}"
    # Use relative links for portability
    [ ! -f "$waybar_dest/style.css" ] && run ln -sf "themes/pink-anime.css" "$waybar_dest/style.css"
    
    # Widget theme links
    local widget
    for widget in aiko-note aiko-player aiko-clock aiko-usercard aiko-weather aiko-list aiko-sys; do
        local w_dir="$waybar_dest/widgets/$widget"
        if [ -d "$w_dir" ] && [ ! -f "$w_dir/theme.css" ]; then
            (cd "$w_dir" && run ln -sf "themes/pink-anime.css" "theme.css")
        fi
    done

    # Add fastfetch to .bashrc if not present
    if [ -f "$HOME/.bashrc" ] && ! grep -q "fastfetch" "$HOME/.bashrc"; then
        log "Adding fastfetch to .bashrc..."
        cat << 'EOF' >> "$HOME/.bashrc"

# Auto-run fastfetch for AikoHyprSetup
if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
EOF
    fi

    log "${MAGENTA}Adjusting permissions...${NC}"
    find "$waybar_dest" -type f -name "*.sh" -exec chmod +x {} +

    log "${MAGENTA}Generating initial themed icons (Pink Anime default)...${NC}"
    if [ -x "$waybar_dest/icon-gen.sh" ]; then
        run "$waybar_dest/icon-gen.sh" "#ff8fbd"
    fi

    log "${MAGENTA}Syncing Fastfetch logo properties...${NC}"
    if [ -x "$waybar_dest/sync-fastfetch.py" ]; then
        run "$waybar_dest/sync-fastfetch.py"
    fi
}

post_install_checks() {
    required_bins=(
        hyprland waybar wofi mako hyprpaper kitty jq playerctl pactl wpctl 
        wl-copy wl-paste cliphist notify-send grim slurp curl
        hyprpicker swappy nm-applet bluetoothctl pavucontrol cava zenity 
        gthumb magick
    )
    missing_required=()

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

# --- Menu System (Configuration) ---

print_header() {
    cat <<EOF
${MAGENTA}${BOLD}
  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ 
  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
  ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
  ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
${NC}
             ${CYAN}AikoHyprSetup v$AIKO_VERSION (Hyprland + Waybar)${NC}
EOF
    echo
}

show_summary() {
    printf "\n${BOLD}${GREEN}=== Installation Summary ===${NC}\n"
    printf "${CYAN}Packages installed:${NC}  %d\n" "$INSTALLED_PKGS"
    printf "${CYAN}Files copied:${NC}       %d\n" "$COPIED_FILES"
    printf "${CYAN}Backups created:${NC}    %d\n" "$BACKUPS_CREATED"
    echo "=============================="
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

# Menu Action Functions
action_full_setup() {
    log "Starting full setup..."
    install_packages
    install_configs
    action_global_aiko "silent"
    post_install_checks
    show_summary
    apply_changes
    return 130
}

action_update_configs() {
    install_configs
    show_summary
    prompt_apply
    return 0
}

action_install_packages() {
    install_packages
    show_summary
    return 0
}

action_check_health() {
    post_install_checks
    return 0
}

action_restart_waybar() {
    apply_changes
    success "Waybar and Hyprland reloaded!"
    return 0
}

action_git_pull() {
    if [ -d "$AIKO_ROOT/.git" ]; then
        log "Updating AikoHyprSetup from GitHub in: $AIKO_ROOT"
        if git -C "$AIKO_ROOT" pull; then
            success "Update successful! Please exit (0) and run ./install.sh again to use the updated version."
        else
            error "Failed to pull updates. Check your connection or git status."
        fi
    else
        warn "Source at $AIKO_ROOT is not a git repository."
        if confirm "Do you want to download the latest version from GitHub?" "n"; then
            TEMP_DIR=$(mktemp -d)
            log "Downloading latest master archive..."
            if curl -L https://github.com/watashi-00/AikoHyprSetup/archive/refs/heads/master.zip -o "$TEMP_DIR/update.zip"; then
                log "Extracting to $AIKO_ROOT..."
                unzip -o -q "$TEMP_DIR/update.zip" -d "$TEMP_DIR"
                EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "AikoHyprSetup-*" | head -n 1)
                if [ -d "$EXTRACTED_DIR" ]; then
                    # Copy all files from extracted dir to current AIKO_ROOT
                    cp -rf "$EXTRACTED_DIR"/* "$AIKO_ROOT/"
                    success "Update successful! Source files updated."
                    printf "${YELLOW}[!]${NC} Please exit (0) and run ./install.sh again to use the updated version.\n"
                    exit 0
                else
                    error "Could not find extracted directory."
                fi
            else
                error "Failed to download update."
            fi
            rm -rf "$TEMP_DIR"
        else
            warn "Non-git updates require 'curl' and 'unzip'. Please update manually."
        fi
    fi
    return 0
}

action_wallpaper_changer() {
    local wp_script="$AIKO_SCRIPTS/wallpaper.sh"
    if [ -f "$wp_script" ]; then
        bash "$wp_script" select
    else
        warn "Wallpaper script not found."
    fi
    return 0
}

action_theme_selector() {
    local theme_script="$AIKO_SCRIPTS/theme-selector.sh"
    if [ -f "$theme_script" ]; then
        bash "$theme_script"
    else
        warn "Theme selector script not found."
    fi
    return 0
}

action_global_aiko() {
    local mode="${1:-normal}"
    local aiko_src="$HOME/.config/waybar/aiko.sh"
    local aiko_dest="/usr/local/bin/aiko"

    if [ ! -f "$aiko_src" ]; then
        if [ "$mode" != "silent" ]; then
            error "Aiko script not found. Install configs first."
        fi
        return 0
    fi

    if [ "$mode" != "silent" ]; then
        log "Setting up 'aiko' command..."
    fi
    
    validate_sudo
    sudo_cmd ln -sf "$aiko_src" "$aiko_dest"
    sudo_cmd chmod +x "$aiko_dest"
    
    if [ "$mode" != "silent" ]; then
        success "Global command 'aiko' is ready!"
    fi
    return 0
}

action_diagnostics() {
    local diag_script="$AIKO_SCRIPTS/diagnostics.sh"
    if [ -f "$diag_script" ]; then
        bash "$diag_script"
    else
        warn "Diagnostics script not found."
    fi
    return 0
}

action_gpu_setup() {
    local gpu_local="$(cd "$AIKO_ROOT/.." && pwd)/gpu_setup/setup.sh"
    if [ -f "$gpu_local" ]; then
        log "Handing over to local GPU Setup Manager..."
        exec sudo bash "$gpu_local"
    else
        log "GPU Setup not found locally. Downloading and running from GitHub..."
        if ! have git; then
            error "Error: 'git' is required to download the GPU Setup Manager."
            return 1
        fi
        local temp_gpu
        temp_gpu=$(mktemp -d)
        if git clone --depth 1 https://github.com/watashi-00/gpu_setup.git "$temp_gpu"; then
            exec sudo bash "$temp_gpu/setup.sh"
        else
            error "Failed to download GPU Setup Manager."
            rm -rf "$temp_gpu"
            return 1
        fi
    fi
}

action_cleanup_backups() {
    cleanup_generated_backups
    return 0
}

action_exit() {
    if [ -t 1 ]; then clear; fi
    log "Exiting..."
    return 127
}

interactive_menu() {
    declare -A labels=(
        [1]="🚀  Full Setup (Recommended)"
        [2]="🎨  Update Configs & Widgets"
        [3]="📦  Install Packages Only"
        [4]="🖼️   Change Wallpaper"
        [5]="🎨  Change Theme"
        [6]="🔄  Restart Waybar"
        [7]="🔍  Check System Health"
        [8]="🆙  Update Setup (Git Pull)"
        [9]="🗑️   Clean Generated Backups"
        [10]="🩺  Environment Diagnostics"
        [11]="🎮  GPU Setup"
        [0]="✘   Exit"
    )

    declare -A actions=(
        [1]="action_full_setup"
        [2]="action_update_configs"
        [3]="action_install_packages"
        [4]="action_wallpaper_changer"
        [5]="action_theme_selector"
        [6]="action_restart_waybar"
        [7]="action_check_health"
        [8]="action_git_pull"
        [9]="action_cleanup_backups"
        [10]="action_diagnostics"
        [11]="action_gpu_setup"
        [0]="action_exit"
    )
    local order=(1 2 3 4 5 6 7 8 9 10 11 0)
    
    menu "" labels actions order
}

# --- CLI Options ---

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Options:
  --no-packages  Do not install system dependencies.
  --no-hypr      Do not install hyprland.conf in ~/.config/hypr.
  --force        Overwrite files without asking.
  --dry-run      Show actions without copying/installing.
  -h, --help     Show this help.

If run without options, opens the interactive menu.
EOF
}

if [ "$#" -gt 0 ]; then
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-packages) INSTALL_PACKAGES=0 ;;
            --no-hypr) INSTALL_HYPR=0 ;;
            --force) FORCE=1 ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done
    [ "$INSTALL_PACKAGES" -eq 1 ] && install_packages
    install_configs
    post_install_checks
    show_summary
else
    interactive_menu
fi
