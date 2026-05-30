#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PACKAGES=1
INSTALL_HYPR=1
FORCE=0
DRY_RUN=0

log() {
    printf '[install] %s\n' "$*"
}

warn() {
    printf '[install][warn] %s\n' "$*" >&2
}

die() {
    printf '[install][error] %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Uso: ./install.sh [opcoes]

Opcoes:
  --no-packages  Nao instala dependencias do sistema.
  --no-hypr      Nao instala hyprland.conf em ~/.config/hypr.
  --force        Sobrescreve arquivos sem perguntar.
  --dry-run      Mostra acoes sem copiar/instalar.
  -h, --help     Mostra esta ajuda.

O instalador cria backups com timestamp antes de substituir configs existentes.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-packages) INSTALL_PACKAGES=0 ;;
        --no-hypr) INSTALL_HYPR=0 ;;
        --force) FORCE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Opcao desconhecida: $1" ;;
    esac
    shift
done

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] %s\n' "$*"
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
                ttf-jetbrains-mono-nerd polkit-kde-agent
            ;;
        apt)
            printf '%s\n' \
                hyprland waybar wofi mako-notifier hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-bin network-manager-gnome grim slurp curl \
                hyprpicker swappy xdg-utils bluez fonts-font-awesome \
                fonts-jetbrains-mono polkit-kde-agent-1
            ;;
        dnf)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde
            ;;
        zypper)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulseaudio wireplumber pavucontrol wl-clipboard \
                cliphist libnotify-tools NetworkManager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
                jetbrains-mono-fonts polkit-kde-agent-6
            ;;
        apk)
            printf '%s\n' \
                hyprland waybar wofi mako hyprpaper kitty jq playerctl cava \
                pipewire pipewire-pulse wireplumber pavucontrol wl-clipboard \
                cliphist libnotify network-manager-applet grim slurp curl \
                hyprpicker swappy xdg-utils bluez font-awesome \
                ttf-jetbrains-mono polkit-kde-agent
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
        warn "Gerenciador de pacotes nao suportado. Pulei dependencias."
        return 0
    fi

    log "Gerenciador detectado: $pm"
    if [ "$DRY_RUN" -eq 1 ]; then
        packages_for_pm "$pm" | sed 's/^/[dry-run] pacote: /'
        return 0
    fi

    if [ "$(id -u)" -ne 0 ] && ! have sudo; then
        warn "sudo nao encontrado. Pulei instalacao de pacotes."
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
        log "Instalando/verificando pacote: $pkg"
        if ! install_one_package "$pm" "$pkg"; then
            warn "Nao consegui instalar '$pkg' pelo $pm. Pode nao existir nessa versao da distro."
            missing="${missing}${pkg} "
        fi
    done < <(packages_for_pm "$pm")

    if [ -n "$missing" ]; then
        warn "Pacotes pendentes: $missing"
        warn "Instale manualmente ou use repositorios da sua distro/AUR/COPR/OBS quando necessario."
    fi
}

backup_path() {
    target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        stamp="$(date +%Y%m%d-%H%M%S)"
        backup="${target}.bak-${stamp}"
        log "Backup: $target -> $backup"
        run mv "$target" "$backup"
    fi
}

copy_file() {
    src="$1"
    dest="$2"

    [ -e "$src" ] || die "Arquivo origem nao encontrado: $src"
    run mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        src_real="$(realpath -m "$src")"
        dest_real="$(realpath -m "$dest")"
        if [ "$src_real" = "$dest_real" ]; then
            log "Origem e destino ja sao o mesmo arquivo: $dest"
            return 0
        fi
    fi

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ "$FORCE" -eq 1 ]; then
            backup_path "$dest"
        else
            backup_path "$dest"
        fi
    fi

    log "Copiando: $src -> $dest"
    run cp -L "$src" "$dest"
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
            log "Copiando diretorio: $src -> $dest"
            run cp -aL "$src" "$dest"
        else
            copy_file "$src" "$dest"
        fi
    done
}

patch_installed_paths() {
    file="$1"
    [ -f "$file" ] || return 0
    run sed -i \
        -e "s#/home/watashi#$HOME#g" \
        -e 's#~/.config/hypr/launcher.sh#~/.config/waybar/launcher.sh#g' \
        -e 's#~/.config/hypr/clipboard-history.sh#~/.config/waybar/clipboard-history.sh#g' \
        "$file"
}

install_configs() {
    waybar_dir="$HOME/.config/waybar"
    hypr_dir="$HOME/.config/hypr"
    mako_dir="$HOME/.config/mako"
    wofi_dir="$HOME/.config/wofi"

    waybar_files=(
        config.jsonc
        config-bottom.jsonc
        config-left.jsonc
        config-screenshot.jsonc
        style.css
        audio-input.sh
        audio-output.sh
        clipboard-history.sh
        clipboard-listener.sh
        launcher.sh
        minimize.sh
        restart-waybar.sh
        screenshot.sh
        spotify-art.sh
        spotify-info.sh
        spotify-playstate.sh
    )

    for file in "${waybar_files[@]}"; do
        copy_file "$SOURCE_DIR/$file" "$waybar_dir/$file"
    done

    copy_dir_contents "$SOURCE_DIR/mako-config" "$mako_dir"
    copy_dir_contents "$SOURCE_DIR/wofi-config" "$wofi_dir"

    if [ "$INSTALL_HYPR" -eq 1 ] && [ -f "$SOURCE_DIR/hypr-config/hyprland.conf" ]; then
        copy_file "$SOURCE_DIR/hypr-config/hyprland.conf" "$hypr_dir/hyprland.conf"
        patch_installed_paths "$hypr_dir/hyprland.conf"
    fi

    patch_installed_paths "$waybar_dir/config.jsonc"
    patch_installed_paths "$waybar_dir/config-left.jsonc"

    run chmod +x \
        "$waybar_dir/audio-input.sh" \
        "$waybar_dir/audio-output.sh" \
        "$waybar_dir/clipboard-history.sh" \
        "$waybar_dir/clipboard-listener.sh" \
        "$waybar_dir/launcher.sh" \
        "$waybar_dir/minimize.sh" \
        "$waybar_dir/restart-waybar.sh" \
        "$waybar_dir/screenshot.sh" \
        "$waybar_dir/spotify-art.sh" \
        "$waybar_dir/spotify-info.sh" \
        "$waybar_dir/spotify-playstate.sh"
}

post_install_checks() {
    required_bins=(hyprland waybar wofi mako hyprpaper kitty jq playerctl pactl wpctl wl-copy wl-paste cliphist notify-send grim slurp curl)
    optional_bins=(hyprpicker swappy nm-applet bluetoothctl pavucontrol cava)
    missing_required=()
    missing_optional=()

    for bin in "${required_bins[@]}"; do
        have "$bin" || missing_required+=("$bin")
    done

    for bin in "${optional_bins[@]}"; do
        have "$bin" || missing_optional+=("$bin")
    done

    if [ "${#missing_required[@]}" -gt 0 ]; then
        warn "Binarios ainda ausentes: ${missing_required[*]}"
    fi

    if [ "${#missing_optional[@]}" -gt 0 ]; then
        warn "Opcionais ausentes: ${missing_optional[*]}"
    fi
}

apply_changes() {
    log "Aplicando configuracoes..."

    if [ -x "$HOME/.config/waybar/restart-waybar.sh" ]; then
        "$HOME/.config/waybar/restart-waybar.sh"
    elif have waybar; then
        pkill waybar 2>/dev/null || true
        waybar --config "$HOME/.config/waybar/config-left.jsonc" --style "$HOME/.config/waybar/style.css" &
        waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css" &
        waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" &
    else
        warn "waybar nao encontrado. Nao reiniciei as barras."
    fi

    if have hyprctl; then
        hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload falhou. Execute manualmente dentro de uma sessao Hyprland."
    else
        warn "hyprctl nao encontrado. Pulei reload do Hyprland."
    fi
}

prompt_finish() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry-run concluido. Nenhuma acao aplicada."
        return 0
    fi

    choice=""

    if have wofi && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        choice="$(printf 'Resetar interface\nSair\n' | wofi --dmenu --prompt 'Instalacao concluida' 2>/dev/null || true)"
    elif [ -t 0 ]; then
        printf '\nInstalacao concluida.\n'
        printf '1) Resetar interface agora\n'
        printf '2) Sair\n'
        printf 'Escolha [1/2]: '
        read -r answer || answer=""
        case "$answer" in
            1|r|R) choice="Resetar interface" ;;
            *) choice="Sair" ;;
        esac
    fi

    case "$choice" in
        "Resetar interface")
            apply_changes
            ;;
        *)
            log "Saindo sem aplicar reload automatico."
            ;;
    esac
}

main() {
    log "Origem do pacote: $SOURCE_DIR"

    if [ "$INSTALL_PACKAGES" -eq 1 ]; then
        install_packages
    else
        log "Instalacao de pacotes desativada."
    fi

    install_configs
    post_install_checks

    log "Concluido."
    prompt_finish
}

main "$@"
