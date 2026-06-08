#!/usr/bin/env bash

# AikoHyprSetup V2 - Configuration Management
# Handles file copying, backups, and path patching.

GENERATED_BACKUPS=()
CREATED_PATHS=()

backup_path() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        local stamp
        stamp="$(date +%Y%m%d-%H%M%S)"
        local backup="${target}.bak-${stamp}"
        log "Backup: $(basename "$target") -> $(basename "$backup")"
        run mv "$target" "$backup"
        GENERATED_BACKUPS+=("$backup")
        BACKUPS_CREATED=$((BACKUPS_CREATED + 1))
    fi
}

copy_file() {
    local src="$1"
    local dest="$2"

    [ -e "$src" ] || die "Source file not found: $src"
    
    # Skip if source and destination are the same physical path
    local src_real
    local dest_real
    src_real=$(realpath -m "$src")
    dest_real=$(realpath -m "$dest")
    if [ "$src_real" = "$dest_real" ]; then
        return 0
    fi

    # Ignore backup files during installation
    if [[ "$(basename "$src")" == *.bak-* ]]; then
        return 0
    fi

    run mkdir -p "$(dirname "$dest")"

    local dest_existed=0
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        dest_existed=1
    fi

    if [ "$dest_existed" -eq 1 ]; then
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
    if [ "$dest_existed" -eq 0 ] && [ -e "$dest" ]; then
        CREATED_PATHS+=("$dest")
    fi
    COPIED_FILES=$((COPIED_FILES + 1))
}

copy_dir_contents() {
    local src_dir="$1"
    local dest_dir="$2"

    [ -d "$src_dir" ] || return 0
    
    # Skip if source and destination are the same physical directory
    local src_dir_real
    local dest_dir_real
    src_dir_real=$(realpath -m "$src_dir")
    dest_dir_real=$(realpath -m "$dest_dir")
    if [ "$src_dir_real" = "$dest_dir_real" ]; then
        return 0
    fi

    run mkdir -p "$dest_dir"

    # Avoid subshell by using process substitution
    while IFS= read -r src; do
        # Ignore backup items
        if [[ "$(basename "$src")" == *.bak-* ]]; then
            continue
        fi

        local dest="$dest_dir/$(basename "$src")"
        if [ -d "$src" ] && [ ! -L "$src" ]; then
            local dest_existed=0
            if [ -e "$dest" ] || [ -L "$dest" ]; then
                dest_existed=1
            fi
            # If destination exists, backup it before copying new directory
            if [ -d "$dest" ] && [ ! -L "$dest" ]; then
                backup_path "$dest"
            fi
            log "Copying directory: ${WHITE}$(basename "$src")${NC}"
            run cp -a "$src" "$dest"
            if [ "$dest_existed" -eq 0 ] && [ -e "$dest" ]; then
                CREATED_PATHS+=("$dest")
            fi
            COPIED_FILES=$((COPIED_FILES + 1))
        else
            copy_file "$src" "$dest"
        fi
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1)
}

patch_installed_paths() {
    local file="$1"
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

setup_gpu_hyprland_config() {
    local hypr_conf="$1"
    [ -f "$hypr_conf" ] || return 0

    # Check if the configuration already has Nvidia-specific environment variables
    if grep -q "AQ_DRM_DEVICES" "$hypr_conf" || grep -q "GBM_BACKEND.*nvidia" "$hypr_conf"; then
        log "Nvidia/Multi-GPU configuration already present in hyprland.conf. Skipping auto-detection."
        return 0
    fi

    # Detect GPUs
    local nv_pci
    nv_pci=$(lspci 2>/dev/null | grep -i "NVIDIA" | head -n 1 | awk '{print $1}')
    
    local primary_pci
    primary_pci=$(lspci 2>/dev/null | grep -i -E "Intel|AMD|ATI" | grep -i -E "VGA|3D" | head -n 1 | awk '{print $1}')

    # Case 1: Nvidia Hybrid (Nvidia + Intel/AMD)
    if [ -n "$nv_pci" ] && [ -n "$primary_pci" ]; then
        local nvidia_card=""
        local primary_card=""
        
        if [ -L "/dev/dri/by-path/pci-$nv_pci-card" ]; then
            nvidia_card=$(readlink -f "/dev/dri/by-path/pci-$nv_pci-card")
        fi
        if [ -L "/dev/dri/by-path/pci-$primary_pci-card" ]; then
            primary_card=$(readlink -f "/dev/dri/by-path/pci-$primary_pci-card")
        fi
        
        # Fallbacks if paths are empty
        [ -z "$nvidia_card" ] && nvidia_card="/dev/dri/card1"
        [ -z "$primary_card" ] && primary_card="/dev/dri/card2"

        warn "We detected a Hybrid GPU setup (Intel/AMD + NVIDIA)."
        if confirm "Would you like to enable multi-GPU / Nvidia optimizations for Hyprland?" "y"; then
            log "Configuring Nvidia and multi-GPU settings for Hyprland..."
            {
                echo ""
                echo "# --- Nvidia and Multi-GPU configuration ---"
                echo "env = LIBVA_DRIVER_NAME,nvidia"
                echo "env = GBM_BACKEND,nvidia-drm"
                echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
                echo "env = XDG_SESSION_TYPE,wayland"
                echo "env = AQ_DRM_DEVICES,$primary_card:$nvidia_card"
                echo "# env = AQ_NO_ATOMIC,1"
                echo "env = WLR_NO_HARDWARE_CURSORS,1"
                echo ""
                echo "cursor {"
                echo "    no_hardware_cursors = true"
                echo "}"
                echo "# ------------------------------------------"
            } >> "$hypr_conf"
            success "GPU optimizations added to hyprland.conf!"
        else
            log "Skipped Nvidia hybrid GPU optimizations."
        fi
        
    # Case 2: Nvidia Single GPU
    elif [ -n "$nv_pci" ]; then
        warn "We detected a single NVIDIA GPU setup."
        if confirm "Would you like to enable Nvidia Wayland optimizations for Hyprland?" "y"; then
            log "Configuring Nvidia single GPU settings..."
            {
                echo ""
                echo "# --- Nvidia Wayland configuration ---"
                echo "env = LIBVA_DRIVER_NAME,nvidia"
                echo "env = GBM_BACKEND,nvidia-drm"
                echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
                echo "env = XDG_SESSION_TYPE,wayland"
                echo "env = WLR_NO_HARDWARE_CURSORS,1"
                echo ""
                echo "cursor {"
                echo "    no_hardware_cursors = true"
                echo "}"
                echo "# -------------------------------------"
            } >> "$hypr_conf"
            success "Nvidia optimizations added to hyprland.conf!"
        else
            log "Skipped Nvidia optimizations."
        fi
    fi
}

install_configs() {
    local waybar_dest="$HOME/.config/waybar"
    local hypr_dest="$HOME/.config/hypr"
    local mako_dest="$HOME/.config/mako"
    local wofi_dest="$HOME/.config/wofi"



    log "${MAGENTA}Installing Waybar configs...${NC}"
    if [ -f "$AIKO_SOURCE_WAYBAR/style.css" ]; then
        copy_file "$AIKO_SOURCE_WAYBAR/style.css" "$waybar_dest/style.css"
    fi

    log "${MAGENTA}Installing Layout Profiles...${NC}"
    if [ -d "$AIKO_SOURCE_WAYBAR/layouts" ]; then
        copy_dir_contents "$AIKO_SOURCE_WAYBAR/layouts" "$waybar_dest/layouts"
        # Standardize paths inside layout configurations
        find "$waybar_dest/layouts" -type f -name "*.jsonc" -exec sed -i "s#@HOME@#$HOME#g;s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    # Set default active layout if not already set
    if [ ! -L "$waybar_dest/active_layout" ] && [ ! -d "$waybar_dest/active_layout" ]; then
        (cd "$waybar_dest" && ln -sf layouts/default active_layout)
    fi

    log "${MAGENTA}Installing helper scripts...${NC}"
    # Scripts now live ONLY in the scripts/ subfolder of the destination
    if [ -d "$AIKO_SCRIPTS" ]; then
        copy_dir_contents "$AIKO_SCRIPTS" "$waybar_dest/scripts"
        # Standardize paths in installed scripts
        find "$waybar_dest/scripts" -type f -exec sed -i "s#@HOME@#$HOME#g;s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    log "${MAGENTA}Installing Installer itself...${NC}"
    copy_file "$REAL_PATH" "$waybar_dest/install.sh"

    log "${MAGENTA}Installing Themes...${NC}"
    if [ -d "$AIKO_THEMES" ]; then
        copy_dir_contents "$AIKO_THEMES" "$waybar_dest/themes"
        find "$waybar_dest/themes" -type f -name "*.css" -exec sed -i "s#@HOME@#$HOME#g;s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
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
        find "$waybar_dest/widgets" -type f \( -name "*.sh" -o -name "*.css" -o -name "*.py" \) -exec sed -i "s#@HOME@#$HOME#g;s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g;s#~/.config#$HOME/.config#g" {} +
    fi

    log "${MAGENTA}Installing Assets...${NC}"
    if [ -d "$AIKO_ASSETS" ]; then
        if [ -f "$waybar_dest/assets/aiko-frame.txt" ]; then
            # Copy all assets except aiko-frame.txt to preserve client's custom edit
            while read -r src; do
                [ "$(basename "$src")" = "aiko-frame.txt" ] && continue
                copy_file "$src" "$waybar_dest/assets/$(basename "$src")"
            done < <(find "$AIKO_ASSETS" -mindepth 1 -maxdepth 1)
        else
            copy_dir_contents "$AIKO_ASSETS" "$waybar_dest/assets"
        fi
    fi

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
        setup_gpu_hyprland_config "$hypr_conf"
        [ -f "$hypr_dest/shortcuts.txt" ] && patch_installed_paths "$hypr_dest/shortcuts.txt"
    fi

    log "${MAGENTA}Installing Desktop Entries...${NC}"
    local app_dir="$HOME/.local/share/applications"
    local icon_dir="$HOME/.local/share/icons"
    mkdir -p "$app_dir" "$icon_dir"
    if [ -d "$AIKO_CONFIGS/applications" ]; then
        copy_dir_contents "$AIKO_CONFIGS/applications" "$app_dir"
        find "$app_dir" -type f -name "aiko-*.desktop" -exec sed -i "s#@HOME@#$HOME#g;s#/home/watashi#$HOME#g;s#\$HOME#$HOME#g" {} +
    fi

    log "${MAGENTA}Installing Kitty and Fastfetch configs...${NC}"
    mkdir -p "$HOME/.config/kitty" "$HOME/.config/fastfetch"
    [ -d "$AIKO_CONFIGS/kitty" ] && copy_dir_contents "$AIKO_CONFIGS/kitty" "$HOME/.config/kitty"

    local fastfetch_dest="$HOME/.config/fastfetch/config.jsonc"
    local temp_client_config="/tmp/fastfetch-client-config.jsonc"
    rm -f "$temp_client_config"

    # If the client already has a config, copy it to a temporary location before we overwrite it
    if [ -f "$fastfetch_dest" ]; then
        cp "$fastfetch_dest" "$temp_client_config"
    fi

    [ -d "$AIKO_CONFIGS/fastfetch" ] && copy_dir_contents "$AIKO_CONFIGS/fastfetch" "$HOME/.config/fastfetch"
    patch_installed_paths "$fastfetch_dest"

    # If there was an existing client config, merge its settings back into the newly installed config
    if [ -f "$temp_client_config" ]; then
        python3 -c "
import json, os, re, sys

def clean_json_content(content):
    # Remove block comments /* ... */
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # Remove single line comments // ...
    content = re.sub(r'//.*', '', content)
    # Remove trailing commas before closing braces/brackets
    content = re.sub(r',\s*([\]}])', r'\1', content)
    return content.strip()

client_path = sys.argv[1]
dest_path = sys.argv[2]

try:
    with open(client_path, 'r') as f:
        client_content = f.read()
    cleaned_client = clean_json_content(client_content)
    client_data = json.loads(cleaned_client)
except Exception as e:
    # If parsing client config failed, exit gracefully
    sys.exit(0)

try:
    with open(dest_path, 'r') as f:
        dest_content = f.read()
    cleaned_dest = clean_json_content(dest_content)
    dest_data = json.loads(cleaned_dest)
except Exception as e:
    sys.exit(0)

# Merge logo settings (source, type, padding, etc.)
if 'logo' in client_data:
    if 'logo' not in dest_data:
        dest_data['logo'] = {}
    for k, v in client_data['logo'].items():
        dest_data['logo'][k] = v

# Merge display settings
if 'display' in client_data:
    if 'display' not in dest_data:
        dest_data['display'] = {}
    for k, v in client_data['display'].items():
        dest_data['display'][k] = v

# Merge modules (overwrite entirely to keep custom modules and layout)
if 'modules' in client_data and client_data['modules']:
    dest_data['modules'] = client_data['modules']

try:
    with open(dest_path, 'w') as f:
        json.dump(dest_data, f, indent=4)
except Exception as e:
    pass
" "$temp_client_config" "$fastfetch_dest" 2>/dev/null
        rm -f "$temp_client_config"
    fi

    log "${MAGENTA}Installing Cava config...${NC}"
    mkdir -p "$HOME/.config/cava"
    [ -d "$AIKO_CONFIGS/cava" ] && copy_dir_contents "$AIKO_CONFIGS/cava" "$HOME/.config/cava"
    patch_installed_paths "$HOME/.config/cava/config"

    # Auto-detect default audio sink and configure it as the input source for Cava
    local detected_source=""
    if command -v pactl >/dev/null 2>&1; then
        detected_source=$(pactl get-default-sink 2>/dev/null || true)
    fi
    if [ -z "$detected_source" ] && command -v wpctl >/dev/null 2>&1; then
        detected_source=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -E 'node\.name' | head -n 1 | awk -F '"' '{print $2}' || true)
    fi
    if [ -z "$detected_source" ] && command -v pactl >/dev/null 2>&1; then
        detected_source=$(pactl info 2>/dev/null | grep "Default Sink" | awk '{print $3}' || true)
    fi

    if [ -n "$detected_source" ]; then
        log "Auto-detected default audio sink: $detected_source"
        sed -i "s#source = auto#source = ${detected_source}.monitor#g" "$HOME/.config/cava/config"
    fi

    log "${MAGENTA}Applying active theme and patching config colors...${NC}"
    local active_theme="pink-anime.css"
    if [ -L "$waybar_dest/style.css" ]; then
        active_theme=$(basename "$(readlink "$waybar_dest/style.css")")
    fi
    
    # Run theme-selector silently to restore theme files, symlinks and config patches
    if [ -f "$waybar_dest/scripts/theme-selector.sh" ]; then
        run env AIKO_ROOT="$waybar_dest" bash "$waybar_dest/scripts/theme-selector.sh" "$active_theme"
    fi

    # Widget theme links
    local widget
    for widget in aiko-note aiko-player aiko-clock aiko-usercard aiko-weather aiko-list aiko-sys aiko-monitors aiko-audio aiko-calendar aiko-timer aiko-recorder; do
        local w_dir="$waybar_dest/widgets/$widget"
        if [ -d "$w_dir" ]; then
            (cd "$w_dir" && run ln -sf "../../themes/$active_theme" "theme.css")
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

    log "${MAGENTA}Cleaning up legacy scripts from root...${NC}"
    for legacy in icon-gen.sh restart-waybar.sh wallpaper.sh theme-selector.sh aiko.sh \
                  audio-input.sh audio-output.sh clipboard-history.sh clipboard-listener.sh \
                  diagnostics.sh icon-listener.sh launcher.sh menu.sh minimize.sh \
                  power-menu.sh screenshot.sh spotify-art.sh spotify-info.sh \
                  spotify-playstate.sh sync-fastfetch.py taskbar-update.sh update-backups.sh; do
        if [ -f "$waybar_dest/$legacy" ] && [ ! -L "$waybar_dest/$legacy" ]; then
            log "Removing legacy script: $legacy"
            run rm -f "$waybar_dest/$legacy"
        fi
    done

    # Write version and branch metadata to target
    log "${MAGENTA}Writing version and branch details...${NC}"
    local src_branch="master"
    local src_hash="unknown"
    
    if [ -d "$AIKO_ROOT/.git" ]; then
        src_branch=$(git -C "$AIKO_ROOT" branch --show-current 2>/dev/null || echo "master")
        src_hash=$(git -C "$AIKO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        local dirname
        dirname=$(basename "$AIKO_ROOT")
        if [[ "$dirname" == AikoHyprSetup-* ]]; then
            src_branch="${dirname#AikoHyprSetup-}"
        fi
        [ -f "$AIKO_ROOT/.version_branch" ] && src_branch=$(cat "$AIKO_ROOT/.version_branch")
        [ -f "$AIKO_ROOT/.version_hash" ] && src_hash=$(cat "$AIKO_ROOT/.version_hash")
    fi
    
    echo "$src_branch" > "$waybar_dest/.version_branch"
    echo "$src_hash" > "$waybar_dest/.version_hash"

    # Get the accent color dynamically from the theme file for icon-gen
    local theme_file="$waybar_dest/themes/$active_theme"
    local accent_color=""
    if [ -f "$theme_file" ]; then
        accent_color=$(grep "@mako-border" "$theme_file" | cut -d':' -f2 | tr -d '[:space:]')
    fi
    [ -z "$accent_color" ] && accent_color="#ff8fbd"

    log "${MAGENTA}Generating initial themed icons ($active_theme default)...${NC}"
    if [ -x "$waybar_dest/scripts/icon-gen.sh" ]; then
        # Run in background to avoid blocking
        "$waybar_dest/scripts/icon-gen.sh" "$accent_color" >/dev/null 2>&1 &
    fi

    log "${MAGENTA}Syncing Fastfetch logo properties...${NC}"
    if [ -x "$waybar_dest/scripts/sync-fastfetch.py" ]; then
        run "$waybar_dest/scripts/sync-fastfetch.py"
    fi
}
