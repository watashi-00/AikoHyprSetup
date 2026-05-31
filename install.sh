#!/usr/bin/env bash
set -euo pipefail

# --- Configurações Iniciais ---
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PACKAGES=1
INSTALL_HYPR=1
FORCE=0
DRY_RUN=0

# --- Cores e Estilo ---
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

# Ícones
CHECK="✔"
WARN="⚠"
ERROR="✘"
INFO="ℹ"
ROCKET="🚀"
PACKAGE="📦"
CONFIG="🎨"
SEARCH="🔍"
RELOAD="🔄"

# --- Carregar Menu Modular ---
if [ -f "$SOURCE_DIR/menu.sh" ]; then
    # shellcheck disable=SC1091
    source "$SOURCE_DIR/menu.sh"
else
    echo "Erro: menu.sh não encontrado em $SOURCE_DIR"
    exit 1
fi

# --- Variáveis de Resumo ---
INSTALLED_PKGS=0
COPIED_FILES=0
BACKUPS_CREATED=0

# --- Funções de Log ---
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

# --- Lógica Interna ---

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
                hyprpicker swappy xdg-utils bluez fontawesome-fonts \
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

    log "Gerenciador detectado: ${BOLD}$pm${NC}"
    if [ "$DRY_RUN" -eq 1 ]; then
        packages_for_pm "$pm" | sed "s/^/${YELLOW}[dry-run]${NC} pacote: /"
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
        printf "  ${CYAN}$PACKAGE${NC} Verificando/Instalando: ${WHITE}%s${NC}..." "$pkg"
        if install_one_package "$pm" "$pkg" >/dev/null 2>&1; then
            printf " ${GREEN}OK${NC}\n"
            INSTALLED_PKGS=$((INSTALLED_PKGS + 1))
        else
            printf " ${RED}FALHA${NC}\n"
            warn "Nao consegui instalar '$pkg' pelo $pm."
            missing="${missing}${pkg} "
        fi
    done < <(packages_for_pm "$pm")

    if [ -n "$missing" ]; then
        warn "Pacotes pendentes: $missing"
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

    [ -e "$src" ] || die "Arquivo origem nao encontrado: $src"
    run mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        src_real="$(realpath -m "$src")"
        dest_real="$(realpath -m "$dest")"
        if [ "$src_real" = "$dest_real" ]; then
            return 0
        fi
        backup_path "$dest"
    fi

    log "Copiando: ${WHITE}$(basename "$src")${NC} -> ${WHITE}$dest${NC}"
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
            log "Copiando diretorio: ${WHITE}$(basename "$src")${NC}"
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
        config.jsonc config-bottom.jsonc config-left.jsonc config-screenshot.jsonc
        style.css audio-input.sh audio-output.sh clipboard-history.sh
        clipboard-listener.sh launcher.sh minimize.sh restart-waybar.sh
        screenshot.sh spotify-art.sh spotify-info.sh spotify-playstate.sh
        wallpaper.sh
    )

    log "${MAGENTA}Instalando arquivos do Waybar...${NC}"
    for file in "${waybar_files[@]}"; do
        copy_file "$SOURCE_DIR/$file" "$waybar_dir/$file"
    done

    log "${MAGENTA}Instalando Mako e Wofi...${NC}"
    copy_dir_contents "$SOURCE_DIR/mako-config" "$mako_dir"
    copy_dir_contents "$SOURCE_DIR/wofi-config" "$wofi_dir"

    if [ "$INSTALL_HYPR" -eq 1 ] && [ -f "$SOURCE_DIR/hypr-config/hyprland.conf" ]; then
        log "${MAGENTA}Instalando Hyprland config...${NC}"
        copy_file "$SOURCE_DIR/hypr-config/hyprland.conf" "$hypr_dir/hyprland.conf"
        patch_installed_paths "$hypr_dir/hyprland.conf"
    fi

    patch_installed_paths "$waybar_dir/config.jsonc"
    patch_installed_paths "$waybar_dir/config-left.jsonc"

    log "${MAGENTA}Ajustando permissões...${NC}"
    run chmod +x \
        "$waybar_dir/audio-input.sh" "$waybar_dir/audio-output.sh" \
        "$waybar_dir/clipboard-history.sh" "$waybar_dir/clipboard-listener.sh" \
        "$waybar_dir/launcher.sh" "$waybar_dir/minimize.sh" \
        "$waybar_dir/restart-waybar.sh" "$waybar_dir/screenshot.sh" \
        "$waybar_dir/spotify-art.sh" "$waybar_dir/spotify-info.sh" \
        "$waybar_dir/spotify-playstate.sh" "$waybar_dir/wallpaper.sh"
}

post_install_checks() {
    required_bins=(hyprland waybar wofi mako hyprpaper kitty jq playerctl pactl wpctl wl-copy wl-paste cliphist notify-send grim slurp curl)
    optional_bins=(hyprpicker swappy nm-applet bluetoothctl pavucontrol cava)
    missing_required=()
    missing_optional=()

    printf "\n${BOLD}--- Verificação de Binários ---${NC}\n"
    for bin in "${required_bins[@]}"; do
        if have "$bin"; then
            printf "  ${GREEN}✔${NC} %-15s ${GREEN}[OK]${NC}\n" "$bin"
        else
            printf "  ${RED}✘${NC} %-15s ${RED}[AUSENTE]${NC}\n" "$bin"
            missing_required+=("$bin")
        fi
    done

    for bin in "${optional_bins[@]}"; do
        if have "$bin"; then
            printf "  ${CYAN}ℹ${NC} %-15s ${GREEN}[OK]${NC}\n" "$bin"
        else
            printf "  ${YELLOW}⚠${NC} %-15s ${YELLOW}[OPCIONAL AUSENTE]${NC}\n" "$bin"
            missing_optional+=("$bin")
        fi
    done

    if [ "${#missing_required[@]}" -gt 0 ]; then
        warn "Binarios criticos ainda ausentes: ${missing_required[*]}"
    fi
}

apply_changes() {
    log "${MAGENTA}Aplicando configuracoes...${NC}"

    if [ -x "$HOME/.config/waybar/wallpaper.sh" ]; then
        run "$HOME/.config/waybar/wallpaper.sh" apply
    fi

    if [ -x "$HOME/.config/waybar/restart-waybar.sh" ]; then
        run "$HOME/.config/waybar/restart-waybar.sh"
    elif have waybar; then
        pkill waybar 2>/dev/null || true
        waybar --config "$HOME/.config/waybar/config-left.jsonc" --style "$HOME/.config/waybar/style.css" &
        waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css" &
        waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" &
    else
        warn "waybar nao encontrado."
    fi

    if have hyprctl; then
        hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload falhou. Execute manualmente no Hyprland."
    fi
}

# --- Sistema de Menu (Configuração) ---

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
             ${CYAN}Instalador do Dotfiles (Hyprland + Waybar)${NC}
EOF
    echo
}

show_summary() {
    printf "\n${BOLD}${GREEN}=== Resumo da Instalação ===${NC}\n"
    printf "${CYAN}Pacotes instalados:${NC}  %d\n" "$INSTALLED_PKGS"
    printf "${CYAN}Arquivos copiados:${NC}   %d\n" "$COPIED_FILES"
    printf "${CYAN}Backups criados:${NC}     %d\n" "$BACKUPS_CREATED"
    echo "=============================="
}

prompt_apply() {
    printf "\nDeseja aplicar as alterações agora? (y/n): "
    read -r choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        apply_changes
    fi
}

# Funções de Ação do Menu
action_full_install() {
    INSTALL_PACKAGES=1
    INSTALL_HYPR=1
    install_packages
    install_configs
    post_install_checks
    show_summary
    prompt_apply
    return 130 # Sair do menu após conclusão
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
    success "Alterações aplicadas!"
    return 0
}

action_exit() {
    if [ -t 1 ]; then clear; fi
    log "Saindo..."
    exit 0
}

interactive_menu() {
    declare -A labels=(
        [0]="🚀  Instalação Completa (Recomendado)"
        [1]="📦  Apenas Instalar Pacotes"
        [2]="🎨  Apenas Copiar Configurações"
        [3]="🔍  Verificar Dependências"
        [4]="🔄  Aplicar Alterações Agora"
        [5]="✘   Sair"
    )
    declare -A actions=(
        [0]="action_full_install"
        [1]="action_install_packages"
        [2]="action_install_configs"
        [3]="action_check_deps"
        [4]="action_apply_changes"
        [5]="action_exit"
    )
    local order=(0 1 2 3 4 5)
    
    menu "" labels actions order
}

# --- CLI Options ---

usage() {
    cat <<EOF
Uso: ./install.sh [opcoes]

Opcoes:
  --no-packages  Nao instala dependencias do sistema.
  --no-hypr      Nao instala hyprland.conf em ~/.config/hypr.
  --force        Sobrescreve arquivos sem perguntar.
  --dry-run      Mostra acoes sem copiar/instalar.
  -h, --help     Mostra esta ajuda.

Se executado sem opcoes, abre o menu interativo.
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
            *) die "Opcao desconhecida: $1" ;;
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
