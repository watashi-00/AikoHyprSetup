#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS="$SCRIPT_DIR/lib/utils.sh"

if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="wallpaper"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
STATE_FILE="$AIKO_ROOT/wallpaper.conf"
HYPRPAPER_CONF="$HYPR_DIR/hyprpaper.conf"

is_animated_file() {
    case "${1,,}" in
        *.gif|*.gifv|*.mp4|*.m4v|*.webm|*.mkv|*.mov|*.avi|*.ogv)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

stop_running() {
    pkill -x hyprpaper >/dev/null 2>&1 || true
    pkill -x mpvpaper >/dev/null 2>&1 || true
    pkill -f linux-wallpaperengine >/dev/null 2>&1 || true
    sleep 0.2
}

load_assignments() {
    assignments=()
    if [ ! -f "$STATE_FILE" ]; then return 0; fi
    while IFS= read -r line; do
        case "$line" in
            assignment=*)
                payload="${line#assignment=}"
                monitor="${payload%%|*}"
                file="${payload#*|}"
                if [ "$monitor" != "$payload" ] && [ -n "$file" ] && [ -e "$file" ]; then
                    assignments+=("$monitor|$file")
                fi
                ;;
        esac
    done < "$STATE_FILE"
}

get_current_for_monitor() {
    local target="$1"
    for entry in "${assignments[@]}"; do
        monitor="${entry%%|*}"
        file="${entry#*|}"
        if [ "$monitor" = "$target" ] || [ "$monitor" = "ALL" ]; then
            echo "$(basename "$file")"
            return
        fi
    done
    echo "None"
}

write_hyprpaper_config() {
    mkdir -p "$HYPR_DIR"
    static_files=()
    static_assignments=()
    for entry in "${assignments[@]}"; do
        monitor="${entry%%|*}"
        file="${entry#*|}"
        if [ -f "$file" ] && ! is_animated_file "$file"; then
            static_assignments+=("$monitor|$file")
            static_files+=("$file")
        fi
    done
    {
        printf '# Managed by wallpaper.sh\nsplash = false\n\n'
        if [ "${#static_files[@]}" -gt 0 ]; then
            printf '%s\n' "${static_files[@]}" | awk '!seen[$0]++' | while IFS= read -r file; do
                [ -n "$file" ] || continue
                printf 'preload = %s\n' "$file"
            done
            printf '\n'
        fi
        for entry in "${static_assignments[@]}"; do
            monitor="${entry%%|*}"
            file="${entry#*|}"
            [ "$monitor" = "ALL" ] && monitor=""
            printf 'wallpaper = %s,%s\n' "$monitor" "$file"
        done
    } > "$HYPRPAPER_CONF"
}

start_hyprpaper() {
    if have hyprpaper; then
        nohup hyprpaper --config "$HYPRPAPER_CONF" >/dev/null 2>&1 &
    else
        warn "hyprpaper not found."
    fi
}

start_mpvpaper() {
    monitor="$1"
    file="$2"
    [ "$monitor" = "ALL" ] && monitor="*"
    if have mpvpaper; then
        # Added --video-unscaled=no --panscan=1.0 to ensure filling the screen (cropping if aspect ratio differs)
        nohup mpvpaper -f -p -o "no-audio --loop-file=inf --hwdec=auto --video-unscaled=no --panscan=1.0" "$monitor" "$file" >/dev/null 2>&1 &
    else
        warn "mpvpaper not found."
    fi
}

crop_image() {
    local input="$1"
    local monitor_name="$2"
    
    if is_animated_file "$input"; then
        echo "$input"
        return 0
    fi

    local choice
    choice=$(zenity --list --title="Wallpaper Framing - $monitor_name" \
        --text="How would you like to frame this image?" \
        --column="Option" --column="Description" \
        "Auto" "Automatic Center-Crop (Detect Resolution)" \
        "Manual" "Open Editor for Manual Crop (gThumb/Swappy)" \
        "Original" "Keep original file (might stretch or have bars)" \
        --width=450 --height=320 2>/dev/null)

    if [ -z "$choice" ] || [ "$choice" = "Original" ]; then
        echo "$input"
        return 0
    fi

    local output_dir="$AIKO_ROOT/wallpapers"
    mkdir -p "$output_dir"
    local output="$output_dir/cropped_$(date +%s).png"

    # Detect monitor resolution for Auto crop
    local width=1920
    local height=1080
    if have hyprctl && [ "$monitor_name" != "ALL" ]; then
        local mon_info
        mon_info=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$monitor_name\")" 2>/dev/null || echo "")
        if [ -n "$mon_info" ]; then
            width=$(echo "$mon_info" | jq -r '.width')
            height=$(echo "$mon_info" | jq -r '.height')
        fi
    fi

    if [ "$choice" = "Auto" ]; then
        log "Applying automatic ${width}x${height} center crop..."
        if have magick; then
            magick "$input" -resize "${width}x${height}^" -gravity center -extent "${width}x${height}" "$output"
            echo "$output"
            return 0
        elif have convert; then
            convert "$input" -resize "${width}x${height}^" -gravity center -extent "${width}x${height}" "$output"
            echo "$output"
            return 0
        else
            warn "ImageMagick not found for Auto crop. Falling back to Manual."
            choice="Manual"
        fi
    fi

    if [ "$choice" = "Manual" ]; then
        if have gthumb; then
            log "Opening gThumb..."
            notify-send "Wallpaper Tool" "Edit -> Crop -> 16:9. Then 'Save As' to: $output" -i gthumb
            cp "$input" "$output"
            gthumb "$output" >/dev/null 2>&1
            echo "$output"
        elif have swappy; then
            log "Opening Swappy..."
            swappy -f "$input" -o "$output"
            echo "$output"
        else
            warn "No editor found. Using original."
            echo "$input"
        fi
    fi
}

select_wallpaper() {
    if ! have zenity; then
        die "zenity is required."
    fi
    load_assignments
    local monitors=()
    if have hyprctl; then
        while read -r name; do monitors+=("$name"); done < <(hyprctl monitors -j | jq -r '.[] | .name')
    fi
    
    # Get current terminal image for menu display
    local current_term_img="None"
    local config_file="$HOME/.config/fastfetch/config.jsonc"
    [ ! -f "$config_file" ] && config_file="$AIKO_ROOT/configs/fastfetch/config.jsonc"
    if [ -f "$config_file" ]; then
        current_term_img=$(jq -r '.logo.source // "None"' "$config_file" | sed "s|^$HOME|~|")
    fi

    local zen_options=(
        "ALL" "All Monitors Change" "$(get_current_for_monitor "ALL")"
    )
    for mon in "${monitors[@]}"; do
        zen_options+=("$mon" "Monitor: $mon" "$(get_current_for_monitor "$mon")")
    done

    local target
    target=$(zenity --list --title="Select Target" \
        --column="ID" --column="Target" --column="Current Setting" \
        --hide-column=1 --width=550 --height=450 \
        "${zen_options[@]}" 2>/dev/null)
    
    if [ -z "$target" ]; then return 0; fi

    local selected_file
    selected_file=$(zenity --file-selection --title="Select Image/Video for $target" \
        --file-filter="Media & Project Files | *.jpg *.png *.webp *.jpeg *.gif *.mp4 *.webm project.json" 2>/dev/null)
    
    if [ -n "$selected_file" ]; then
        # If project.json is selected, use its parent folder as the target
        if [[ "$selected_file" == */project.json ]]; then
            selected_file="$(dirname "$selected_file")"
        fi
        
        # CROP STEP (Only for static image files, skip for directories/animated files)
        if [ -f "$selected_file" ]; then
            selected_file=$(crop_image "$selected_file" "$target")
        fi
        
        if [ "$target" = "ALL" ]; then
            printf "assignment=ALL|%s\n" "$selected_file" > "$STATE_FILE"
        else
            local new_entries=()
            local found=0
            local has_all=0
            local all_file=""
            for entry in "${assignments[@]}"; do
                m="${entry%%|*}"
                f="${entry#*|}"
                if [ "$m" = "ALL" ]; then has_all=1; all_file="$f"; break; fi
            done
            if [ "$has_all" -eq 1 ]; then
                for mon in "${monitors[@]}"; do
                    if [ "$mon" = "$target" ]; then new_entries+=("$mon|$selected_file"); else new_entries+=("$mon|$all_file"); fi
                done
            else
                for entry in "${assignments[@]}"; do
                    m="${entry%%|*}"; f="${entry#*|}";
                    if [ "$m" = "$target" ]; then new_entries+=("$m|$selected_file"); found=1; else new_entries+=("$m|$f"); fi
                done
                [ "$found" -eq 0 ] && new_entries+=("$target|$selected_file")
            fi
            printf "" > "$STATE_FILE"
            for entry in "${new_entries[@]}"; do printf "assignment=%s\n" "$entry" >> "$STATE_FILE"; done
        fi
        
        # Check if active theme is dynamic-wall
        local is_dynamic=0
        local waybar_style="$AIKO_ROOT/style.css"
        [ ! -f "$waybar_style" ] && waybar_style="$AIKO_ROOT/waybar/style.css"
        if [ -L "$waybar_style" ]; then
            local target
            target=$(readlink "$waybar_style")
            if [[ "$target" == *dynamic-wall* ]]; then
                is_dynamic=1
            fi
        fi

        if [ "$is_dynamic" -eq 1 ] && [ -f "$AIKO_SCRIPTS/aiko-wall-sync.py" ]; then
            python3 "$AIKO_SCRIPTS/aiko-wall-sync.py" "$selected_file"
        else
            apply_wallpaper
        fi
    fi
}

apply_wallpaper() {
    load_assignments
    if [ "${#assignments[@]}" -eq 0 ]; then
        if [ -f "$HYPRPAPER_CONF" ]; then stop_running; start_hyprpaper; fi
        return 0
    fi
    local can_live_update=0
    pgrep -x hyprpaper >/dev/null && can_live_update=1
    stop_running
    write_hyprpaper_config
    if [ -s "$HYPRPAPER_CONF" ]; then grep -q '^wallpaper =' "$HYPRPAPER_CONF" && start_hyprpaper; fi
    for entry in "${assignments[@]}"; do
        monitor="${entry%%|*}"; file="${entry#*|}";
        
        local target_file="$file"
        local is_wpe=0
        local wpe_type=""
        
        # If it is a Wallpaper Engine project directory
        if [ -d "$file" ] && [ -f "$file/project.json" ]; then
            is_wpe=1
            wpe_type=$(jq -r '.type // "Scene"' "$file/project.json" 2>/dev/null || echo "Scene")
            local wpe_file=$(jq -r '.file // ""' "$file/project.json" 2>/dev/null || echo "")
            if [ -n "$wpe_file" ] && [ -f "$file/$wpe_file" ]; then
                target_file="$file/$wpe_file"
            fi
        fi
        
        if [ "$is_wpe" -eq 1 ] && [ "$wpe_type" != "Video" ] && have linux-wallpaperengine; then
            log "Starting linux-wallpaperengine for $monitor..."
            nohup linux-wallpaperengine --screen-assets "$monitor" "$file" >/dev/null 2>&1 &
        elif is_animated_file "$target_file"; then
            start_mpvpaper "$monitor" "$target_file"
        else
            if [ "$can_live_update" -eq 1 ] && have hyprctl; then
                (
                    sleep 0.5
                    hyprctl hyprpaper unload all >/dev/null 2>&1 || true
                    hyprctl hyprpaper preload "$target_file" >/dev/null 2>&1 || true
                    local mon_t="$monitor"; [ "$mon_t" = "ALL" ] && mon_t=""
                    hyprctl hyprpaper wallpaper "$mon_t,$target_file" >/dev/null 2>&1 || true
                ) &
            fi
        fi
    done
}

case "${1:-apply}" in
    apply|start) apply_wallpaper ;;
    select) select_wallpaper ;;
    stop) stop_running ;;
    *) die "Usage: $0 {apply|start|select|stop}" ;;
esac
