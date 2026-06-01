#!/usr/bin/env bash
set -euo pipefail

# --- Initial Settings ---
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PACKAGES=1
INSTALL_HYPR=1
FORCE=0
DRY_RUN=0

# --- Colors and Style ---
NC=$'\e[0m'
BOLD=$'\e[1m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
MAGENTA=$'\e[0;35m'
CYAN=$'\e[0;36m'
WHITE=$'\e[1;37m'
REVERSED=$(tput rev 2>/dev/null || echo $'\e[7m')

# Icons
CHECK="✔"
WARN="⚠"
ERROR="✘"
INFO="ℹ"
ROCKET="🚀"
PACKAGE="📦"
CONFIG="🎨"
SEARCH="🔍"
RELOAD="🔄"

# --- Load Modular Menu ---
if [ -f "$SOURCE_DIR/scripts/menu.sh" ]; then
    # shellcheck disable=SC1091
    source "$SOURCE_DIR/scripts/menu.sh"
else
    echo "Error: menu.sh not found in $SOURCE_DIR/scripts"
    exit 1
fi

# --- Summary Variables ---
INSTALLED_PKGS=0
COPIED_FILES=0
BACKUPS_CREATED=0

# --- Log Functions ---
log() {
    printf "${BLUE}[install]${NC} %s\n" "$*"
}

success() {
    printf "${GREEN}[$CHECK]${NC} %s\n" "$*"
}

warn() {
    printf "${YELLOW}[$WARN]${NC} %s\n" "$*" >&2
}

error() {
    printf "${RED}[$ERROR]${NC} %s\n" "$*" >&2
}

die() {
    error "$*"
    exit 1
}

# --- Internal Logic ---

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "${YELLOW}[dry-run]${NC} %s\n" "$*"
    else
        "$@"
    fi
}

have() {
    command -v "$1" >/dev/null 2>&1
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
        printf "  ${CYAN}$PACKAGE${NC} Checking/Installing: ${WHITE}%s${NC}..." "$pkg"
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
    run cp -L "$src" "$dest"
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
            [ -e "$dest" ] && backup_path "$dest"
            log "Copying directory: ${WHITE}$(basename "$src")${NC}"
            run cp -aL "$src" "$dest"
            COPIED_FILES=$((COPIED_FILES + 1))
        else
            copy_file "$src" "$dest"
        fi
    done
}

patch_installed_paths() {
    file="$1"
    [ -f "$file" ] || return 0
    # Replace literal /home/watashi and literal $HOME with the actual $HOME value
    run sed -i \
        -e "s#/home/watashi#$HOME#g" \
        -e "s#\$HOME#$HOME#g" \
        -e "s#~/.config#$HOME/.config#g" \
        "$file"
}

install_configs() {
    waybar_dir="$HOME/.config/waybar"
    hypr_dir="$HOME/.config/hypr"
    mako_dir="$HOME/.config/mako"
    wofi_dir="$HOME/.config/wofi"

    waybar_files=(
        config.jsonc config-bottom.jsonc config-left.jsonc config-screenshot.jsonc
    )

    scripts=(
        audio-input.sh audio-output.sh clipboard-history.sh
        clipboard-listener.sh launcher.sh menu.sh minimize.sh restart-waybar.sh
        screenshot.sh spotify-art.sh spotify-info.sh spotify-playstate.sh
        wallpaper.sh power-menu.sh theme-selector.sh aiko.sh icon-gen.sh
    )

    log "${MAGENTA}Installing Waybar configs...${NC}"
    for file in "${waybar_files[@]}"; do
        copy_file "$SOURCE_DIR/waybar/$file" "$waybar_dir/$file"
        patch_installed_paths "$waybar_dir/$file"
    done

    log "${MAGENTA}Installing helper scripts...${NC}"
    for file in "${scripts[@]}"; do
        copy_file "$SOURCE_DIR/scripts/$file" "$waybar_dir/$file"
        patch_installed_paths "$waybar_dir/$file"
    done

    log "${MAGENTA}Installing Installer itself...${NC}"
    copy_file "$SOURCE_DIR/install.sh" "$waybar_dir/install.sh"
    copy_dir_contents "$SOURCE_DIR/scripts" "$waybar_dir/scripts"
    
    # Patch all scripts in the scripts/ subfolder too
    find "$waybar_dir/scripts" -type f -name "*.sh" -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +

    log "${MAGENTA}Installing Themes...${NC}"
    copy_dir_contents "$SOURCE_DIR/themes" "$waybar_dir/themes"
    # Patch paths in themes just in case
    find "$waybar_dir/themes" -type f -name "*.css" -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +

    log "${MAGENTA}Installing Mako and Wofi...${NC}"
    copy_dir_contents "$SOURCE_DIR/configs/mako" "$mako_dir"
    copy_dir_contents "$SOURCE_DIR/configs/wofi" "$wofi_dir"
    patch_installed_paths "$mako_dir/config"
    patch_installed_paths "$wofi_dir/config"
    patch_installed_paths "$wofi_dir/style.css"

    log "${MAGENTA}Installing Widgets...${NC}"
    copy_dir_contents "$SOURCE_DIR/widgets" "$waybar_dir/widgets"
    find "$waybar_dir/widgets" -type f \( -name "*.sh" -o -name "*.css" -o -name "*.py" \) -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +

    log "${MAGENTA}Installing Assets...${NC}"
    copy_dir_contents "$SOURCE_DIR/assets" "$waybar_dir/assets"

    log "${MAGENTA}Installing Hyprland config...${NC}"
    if [ "$INSTALL_HYPR" -eq 1 ] && [ -d "$SOURCE_DIR/configs/hypr" ]; then
        copy_dir_contents "$SOURCE_DIR/configs/hypr" "$hypr_dir"
        patch_installed_paths "$hypr_dir/hyprland.conf"
        [ -f "$hypr_dir/shortcuts.txt" ] && patch_installed_paths "$hypr_dir/shortcuts.txt"
    fi

    log "${MAGENTA}Installing Desktop Entries...${NC}"
    local app_dir="$HOME/.local/share/applications"
    mkdir -p "$app_dir"
    copy_dir_contents "$SOURCE_DIR/configs/applications" "$app_dir"
    # Patch paths in desktop entries
    find "$app_dir" -type f -name "aiko-*.desktop" -exec sed -i "s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g" {} +

    log "${MAGENTA}Installing Kitty and Fastfetch configs...${NC}"
    mkdir -p "$HOME/.config/kitty" "$HOME/.config/fastfetch"
    copy_dir_contents "$SOURCE_DIR/configs/kitty" "$HOME/.config/kitty"
    copy_dir_contents "$SOURCE_DIR/configs/fastfetch" "$HOME/.config/fastfetch"
    patch_installed_paths "$HOME/.config/fastfetch/config.jsonc"

    log "${MAGENTA}Creating default theme links...${NC}"
    # Use relative links for portability
    [ ! -f "$waybar_dir/style.css" ] && run ln -sf "themes/pink-anime.css" "$waybar_dir/style.css"
    
    # Widget theme links
    local widget
    for widget in aiko-note aiko-player aiko-clock aiko-usercard aiko-weather aiko-list aiko-sys; do
        local w_dir="$waybar_dir/widgets/$widget"
        if [ -d "$w_dir" ] && [ ! -f "$w_dir/theme.css" ]; then
            run ln -sf "themes/pink-anime.css" "$w_dir/theme.css"
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
    find "$waybar_dir" -type f -name "*.sh" -exec chmod +x {} +

    log "${MAGENTA}Generating initial themed icons (Pink Anime default)...${NC}"
    if [ -x "$waybar_dir/icon-gen.sh" ]; then
        run "$waybar_dir/icon-gen.sh" "#ff8fbd"
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
            printf "  ${GREEN}✔${NC} %-15s ${GREEN}[OK]${NC}\n" "$bin"
        else
            printf "  ${RED}✘${NC} %-15s ${RED}[MISSING]${NC}\n" "$bin"
            missing_required+=("$bin")
        fi
    done

    if [ "${#missing_required[@]}" -gt 0 ]; then
        warn "Critical binaries still missing: ${missing_required[*]}"
    fi
}

apply_changes() {
    log "${MAGENTA}Applying configurations...${NC}"

    local waybar_dir="$HOME/.config/waybar"
    local local_restart="$SOURCE_DIR/scripts/restart-waybar.sh"

    if [ -f "$local_restart" ]; then
        log "Using source restart script for immediate application..."
        run bash "$local_restart"
    elif [ -x "$waybar_dir/restart-waybar.sh" ]; then
        run "$waybar_dir/restart-waybar.sh"
    elif have waybar; then
        pkill waybar 2>/dev/null || true
        waybar --config "$waybar_dir/config-left.jsonc" --style "$waybar_dir/style.css" &
        waybar --config "$waybar_dir/config.jsonc" --style "$waybar_dir/style.css" &
        waybar --config "$waybar_dir/config-bottom.jsonc" --style "$waybar_dir/style.css" &
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
             ${CYAN}AikoHyprSetup (Hyprland + Waybar)${NC}
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

prompt_apply() {
    printf "\nApply changes now? (y/n): "
    read -r choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        apply_changes
    fi
}

# Menu Action Functions
action_full_install() {
    INSTALL_PACKAGES=1
    INSTALL_HYPR=1
    install_packages
    install_configs
    post_install_checks
    show_summary
    prompt_apply
    return 130 # Exit menu after completion
}

action_install_packages() {
    install_packages
    show_summary
    return 130
}

action_install_configs() {
    install_configs
    show_summary
    return 130
}

action_check_deps() {
    post_install_checks
    return 0
}

action_apply_changes() {
    apply_changes
    success "Changes applied!"
    return 0
}

action_wallpaper_changer() {
    local wp_script="$SOURCE_DIR/scripts/wallpaper.sh"
    
    if [ -f "$wp_script" ]; then
        log "Using local wallpaper script..."
        bash "$wp_script" select
        success "Wallpaper process completed!"
    elif [ -x "$HOME/.config/waybar/wallpaper.sh" ]; then
        "$HOME/.config/waybar/wallpaper.sh" select
        success "Wallpaper process completed!"
    else
        warn "Wallpaper script not found. Please install configurations first."
    fi
    return 0
}

action_theme_selector() {
    local theme_script="$SOURCE_DIR/scripts/theme-selector.sh"
    if [ -f "$theme_script" ]; then
        bash "$theme_script"
    elif [ -x "$HOME/.config/waybar/theme-selector.sh" ]; then
        "$HOME/.config/waybar/theme-selector.sh"
    else
        warn "Theme selector script not found."
    fi
    return 0
}

action_global_aiko() {
    local aiko_src="$HOME/.config/waybar/aiko.sh"
    local aiko_dest="/usr/local/bin/aiko"

    if [ ! -f "$aiko_src" ]; then
        error "Aiko script not found at $aiko_src. Please run 'Copy Configurations' first."
        return 0
    fi

    log "Setting up 'aiko' as a global command..."
    validate_sudo
    sudo_cmd ln -sf "$aiko_src" "$aiko_dest"
    sudo_cmd chmod +x "$aiko_dest"
    
    if have aiko; then
        success "Global command 'aiko' is ready! Try running: aiko --help"
    else
        warn "Could not verify 'aiko' command. Check if /usr/local/bin is in your PATH."
    fi
    return 0
}

action_exit() {
    if [ -t 1 ]; then clear; fi
    log "Exiting..."
    exit 0
}

interactive_menu() {
    declare -A labels=(
        [1]="🚀  Full Installation (Recommended)"
        [2]="📦  Install Packages Only"
        [3]="🎨  Copy Configurations Only"
        [4]="🔍  Check Dependencies"
        [5]="🔄  Apply Changes Now"
        [6]="🖼️   Update Wallpaper"
        [7]="🎨  Select Theme"
        [8]="🌍  Make 'aiko' Global Command"
        [0]="✘   Exit"
    )

    declare -A actions=(
        [1]="action_full_install"
        [2]="action_install_packages"
        [3]="action_install_configs"
        [4]="action_check_deps"
        [5]="action_apply_changes"
        [6]="action_wallpaper_changer"
        [7]="action_theme_selector"
        [8]="action_global_aiko"
        [0]="action_exit"
    )
    local order=(1 2 3 4 5 6 7 8 0)
    
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
