#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
WAYBAR_DIR="$CONFIG_HOME/waybar"
HYPR_DIR="$CONFIG_HOME/hypr"
STATE_FILE="$WAYBAR_DIR/wallpaper.conf"
HYPRPAPER_CONF="$HYPR_DIR/hyprpaper.conf"

# Log to stderr to avoid capturing in variables
log() {
    printf "${BLUE:-}[wallpaper]${NC:-} %s\n" "$*" >&2
}

warn() {
    printf "${YELLOW:-}[wallpaper][warn]${NC:-} %s\n" "$*" >&2
}

die() {
    printf "${RED:-}[wallpaper][error]${NC:-} %s\n" "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

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
                if [ "$monitor" != "$payload" ] && [ -n "$file" ] && [ -f "$file" ]; then
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
        if ! is_animated_file "$file"; then
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
        nohup mpvpaper -f -p -o "no-audio --loop-file=inf" "$monitor" "$file" >/dev/null 2>&1 &
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
        "Auto" "Automatic Center-Crop to 16:9 (Fastest)" \
        "Manual" "Open Editor for Manual Crop (gThumb/Swappy)" \
        "Original" "Keep original file (might stretch or have bars)" \
        --width=450 --height=320 2>/dev/null)

    if [ -z "$choice" ] || [ "$choice" = "Original" ]; then
        echo "$input"
        return 0
    fi

    local output_dir="$WAYBAR_DIR/wallpapers"
    mkdir -p "$output_dir"
    local output="$output_dir/cropped_$(date +%s).png"

    if [ "$choice" = "Auto" ]; then
        log "Applying automatic 16:9 center crop..."
        if have magick; then
            magick "$input" -resize "1920x1080^" -gravity center -extent 1920x1080 "$output"
            echo "$output"
            return 0
        elif have convert; then
            convert "$input" -resize "1920x1080^" -gravity center -extent 1920x1080 "$output"
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
    local zen_options=("ALL" "All Monitors Change" "$(get_current_for_monitor "ALL")")
    for mon in "${monitors[@]}"; do
        zen_options+=("$mon" "Monitor: $mon" "$(get_current_for_monitor "$mon")")
    done
    local target
    target=$(zenity --list --title="Select Target Monitor" \
        --column="ID" --column="Monitor" --column="Current Wallpaper" \
        --hide-column=1 --width=500 --height=400 \
        "${zen_options[@]}" 2>/dev/null)
    if [ -z "$target" ]; then return 0; fi
    local selected_file
    selected_file=$(zenity --file-selection --title="Select Image/Video for $target" \
        --file-filter="Media | *.jpg *.png *.webp *.jpeg *.gif *.mp4 *.webm" 2>/dev/null)
    if [ -n "$selected_file" ]; then
        # CROP STEP
        selected_file=$(crop_image "$selected_file" "$target")
        
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
        apply_wallpaper
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
        if is_animated_file "$file"; then
            start_mpvpaper "$monitor" "$file"
        else
            if [ "$can_live_update" -eq 1 ] && have hyprctl; then
                (
                    sleep 0.5
                    hyprctl hyprpaper unload all >/dev/null 2>&1 || true
                    hyprctl hyprpaper preload "$file" >/dev/null 2>&1 || true
                    local mon_t="$monitor"; [ "$mon_t" = "ALL" ] && mon_t=""
                    hyprctl hyprpaper wallpaper "$mon_t,$file" >/dev/null 2>&1 || true
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
