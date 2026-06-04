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
    local pm="$1"
    local pkg="$2"

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
