#!/usr/bin/env bash
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
WAYBAR_DIR="$CONFIG_HOME/waybar"
HYPR_DIR="$CONFIG_HOME/hypr"
STATE_FILE="$WAYBAR_DIR/wallpaper.conf"
HYPRPAPER_CONF="$HYPR_DIR/hyprpaper.conf"

log() {
    printf '[wallpaper] %s\n' "$*"
}

warn() {
    printf '[wallpaper][warn] %s\n' "$*" >&2
}

die() {
    printf '[wallpaper][error] %s\n' "$*" >&2
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
    sleep 0.2 # Give processes time to close
}

load_assignments() {
    assignments=()

    if [ ! -f "$STATE_FILE" ]; then
        return 0
    fi

    while IFS= read -r line; do
        case "$line" in
            assignment=*)
                payload="${line#assignment=}"
                monitor="${payload%%|*}"
                file="${payload#*|}"
                if [ "$monitor" != "$payload" ] && [ -n "$file" ]; then
                    if [ -f "$file" ]; then
                        assignments+=("$monitor|$file")
                    else
                        warn "Wallpaper not found: $file"
                    fi
                fi
                ;;
        esac
    done < "$STATE_FILE"
}

get_current_for_monitor() {
    local target="$1"
    local entry
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
        printf '# Managed by wallpaper.sh\n'
        printf 'splash = false\n'
        printf '\n'

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
            if [ "$monitor" = "ALL" ]; then
                printf 'wallpaper = ,%s\n' "$file"
            else
                printf 'wallpaper = %s,%s\n' "$monitor" "$file"
            fi
        done
    } > "$HYPRPAPER_CONF"
}

start_hyprpaper() {
    if have hyprpaper; then
        nohup hyprpaper --config "$HYPRPAPER_CONF" >/dev/null 2>&1 &
    else
        warn "hyprpaper not found. Skipping static wallpaper."
    fi
}

start_mpvpaper() {
    monitor="$1"
    file="$2"
    
    # mpvpaper uses '*' for all monitors
    [ "$monitor" = "ALL" ] && monitor="*"
    
    if have mpvpaper; then
        nohup mpvpaper -f -p -o "no-audio --loop-file=inf" "$monitor" "$file" >/dev/null 2>&1 &
    else
        warn "mpvpaper not found for animated wallpaper: $file"
    fi
}

select_wallpaper() {
    if ! have zenity; then
        die "zenity is required for graphical file selection. Please install it."
    fi

    load_assignments
    
    # Get active monitors
    local monitors=()
    if have hyprctl; then
        while read -r name; do
            monitors+=("$name")
        done < <(hyprctl monitors -j | jq -r '.[] | .name')
    fi

    # Build Zenity list options
    local zen_options=("ALL" "All Monitors Change" "$(get_current_for_monitor "ALL")")
    for mon in "${monitors[@]}"; do
        zen_options+=("$mon" "Monitor: $mon" "$(get_current_for_monitor "$mon")")
    done

    local choice
    choice=$(zenity --list --title="Select Target Monitor" \
        --column="ID" --column="Monitor" --column="Current Wallpaper" \
        --hide-column=1 --width=500 --height=400 \
        "${zen_options[@]}")

    if [ -z "$choice" ]; then
        log "Selection cancelled."
        return 0
    fi

    local selected_file
    selected_file=$(zenity --file-selection --title="Select Wallpaper for $choice" \
        --file-filter="Images & Videos | *.jpg *.png *.webp *.jpeg *.gif *.mp4 *.webm")

    if [ -n "$selected_file" ]; then
        log "Selected for $choice: $selected_file"
        
        # Update STATE_FILE
        if [ "$choice" = "ALL" ]; then
            # Overwrite everything with a single ALL entry
            printf "assignment=ALL|%s\n" "$selected_file" > "$STATE_FILE"
        else
            # Remove existing entries for this monitor or ALL
            local new_entries=()
            local found=0
            
            # If we currently have an 'ALL' entry and we are setting a specific one,
            # we need to split 'ALL' into individual monitors minus the current choice.
            local has_all=0
            local all_file=""
            for entry in "${assignments[@]}"; do
                m="${entry%%|*}"
                f="${entry#*|}"
                if [ "$m" = "ALL" ]; then
                    has_all=1
                    all_file="$f"
                    break
                fi
            done

            if [ "$has_all" -eq 1 ]; then
                # Expand ALL to individual monitors
                for mon in "${monitors[@]}"; do
                    if [ "$mon" = "$choice" ]; then
                        new_entries+=("$mon|$selected_file")
                    else
                        new_entries+=("$mon|$all_file")
                    fi
                done
            else
                # Just update the specific monitor or add it
                for entry in "${assignments[@]}"; do
                    m="${entry%%|*}"
                    f="${entry#*|}"
                    if [ "$m" = "$choice" ]; then
                        new_entries+=("$m|$selected_file")
                        found=1
                    else
                        new_entries+=("$m|$f")
                    fi
                done
                [ "$found" -eq 0 ] && new_entries+=("$choice|$selected_file")
            fi

            # Save new entries
            printf "" > "$STATE_FILE"
            for entry in "${new_entries[@]}"; do
                printf "assignment=%s\n" "$entry" >> "$STATE_FILE"
            done
        fi
        
        apply_wallpaper
    else
        log "No file selected."
    fi
}

apply_wallpaper() {
    load_assignments

    if [ "${#assignments[@]}" -eq 0 ]; then
        if [ -f "$HYPRPAPER_CONF" ]; then
            log "No new wallpaper found. Reapplying $HYPRPAPER_CONF"
            stop_running
            start_hyprpaper
        else
            warn "No wallpaper configured in $STATE_FILE"
        fi
        return 0
    fi

    # Try live update if hyprpaper is running and we have static assignments
    local can_live_update=0
    if pgrep -x hyprpaper >/dev/null; then
        can_live_update=1
    fi

    stop_running
    write_hyprpaper_config

    if [ -s "$HYPRPAPER_CONF" ]; then
        if grep -q '^wallpaper =' "$HYPRPAPER_CONF"; then
            start_hyprpaper
        fi
    fi

    for entry in "${assignments[@]}"; do
        monitor="${entry%%|*}"
        file="${entry#*|}"
        if is_animated_file "$file"; then
            start_mpvpaper "$monitor" "$file"
        else
            # If it was running, we can also try to force a reload via hyprctl
            if [ "$can_live_update" -eq 1 ] && have hyprctl; then
                (
                    sleep 0.5 # Wait for new hyprpaper to be ready
                    hyprctl hyprpaper unload all >/dev/null 2>&1 || true
                    hyprctl hyprpaper preload "$file" >/dev/null 2>&1 || true
                    local mon_target="$monitor"
                    [ "$mon_target" = "ALL" ] && mon_target=""
                    hyprctl hyprpaper wallpaper "$mon_target,$file" >/dev/null 2>&1 || true
                ) &
            fi
        fi
    done
}

case "${1:-apply}" in
    apply|start)
        apply_wallpaper
        ;;
    select)
        select_wallpaper
        ;;
    stop)
        stop_running
        ;;
    *)
        die "Usage: $0 {apply|start|select|stop}"
        ;;
esac
