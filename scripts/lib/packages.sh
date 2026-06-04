#!/usr/bin/env bash

# AikoHyprSetup V2 - Package Management
# Handles detection and installation of system dependencies.

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
                python-gobject socat fastfetch
            ;;
        apt)
            printf '%s\n' \
                hyprland waybar wofi mako-notifier hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-bin network-manager-gnome grim slurp curl \
                hyprpicker swappy xdg-utils bluez fonts-font-awesome \
                fonts-jetbrains-mono polkit-kde-agent-1 zenity gthumb imagemagick \
                python3-gi socat fastfetch
            ;;
        dnf)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde zenity gthumb ImageMagick \
                python3-gobject socat fastfetch
            ;;
        zypper)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-tools NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde-agent-6 zenity gthumb ImageMagick \
                python3-gobject socat fastfetch
            ;;
        apk)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify network-manager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                ttf-jetbrains-mono polkit-kde-agent zenity gthumb imagemagick \
                py3-gobject3 socat fastfetch
            ;;
    esac
}

install_one_package() {
    local pm="$1"
    local pkg="$2"

    # Specialized logic for Waybar on Arch Linux to ensure feature-rich version
    if [ "$pm" = "pacman" ] && [ "$pkg" = "waybar" ]; then
        if have yay; then
            log "Attempting to install waybar-hyprland via yay..."
            yay -S --needed --noconfirm waybar-hyprland && return 0
        elif have paru; then
            log "Attempting to install waybar-hyprland via paru..."
            paru -S --needed --noconfirm waybar-hyprland && return 0
        fi
        # If no AUR helper, try official waybar but handle potential conflict
        if sudo_cmd pacman -S --needed --noconfirm waybar; then
            return 0
        else
            warn "Official waybar failed. Trying to resolve conflict..."
            # Try to install providing waybar (often resolves conflicts with -git versions)
            sudo_cmd pacman -S --needed --noconfirm waybar-hyprland || return 1
        fi
        return 0
    fi

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
    local pm
    pm="$(pm_detect)"
    if [ "$pm" = unknown ]; then
        warn "Package manager not supported. Skipping dependencies."
        return 0
    fi

    validate_sudo

    log "Detected package manager: ${BOLD}$pm${NC}"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        packages_for_pm "$pm" | sed "s/^/${YELLOW}[dry-run]${NC} package: /"
        return 0
    fi

    if [ "$(id -u)" -ne 0 ] && ! have sudo; then
        warn "sudo not found. Skipping package installation."
        return 0
    fi

    case "$pm" in
        pacman) sudo_cmd pacman -Sy ;;
        apt) sudo_cmd apt-get update ;;
        zypper) sudo_cmd zypper --non-interactive refresh ;;
        apk) sudo_cmd apk update ;;
    esac

    missing=""
    local total_packages
    total_packages=$(packages_for_pm "$pm" | wc -l)
    local package_index=0

    while IFS= read -r pkg; do
        [ -n "$pkg" ] || continue
        package_index=$((package_index + 1))
        printf "  ${CYAN}%s${NC} [%d/%d] Checking/Installing: ${WHITE}%s${NC}..." "$ICON_PACKAGE" "$package_index" "$total_packages" "$pkg"
        
        # Create a temp file for error output
        local err_log
        err_log=$(mktemp)
        
        if install_one_package "$pm" "$pkg" >/dev/null 2>"$err_log"; then
            printf " ${GREEN}OK${NC}\n"
            INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
        else
            printf " ${RED}FAILED${NC}\n"
            local err_msg
            err_msg=$(cat "$err_log" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-100)
            [ -n "$err_msg" ] && echo "      ${RED}Error:${NC} $err_msg..."
            warn "Could not install '$pkg' via $pm."
            missing="${missing}${pkg} "
        fi
        rm -f "$err_log"
    done < <(packages_for_pm "$pm")

    if [ -n "$missing" ]; then
        warn "Pending packages: $missing"
    fi
}
