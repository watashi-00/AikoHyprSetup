#!/usr/bin/env bash
set -e

if ! command -v pactl >/dev/null 2>&1; then
    exit 0
fi

case "${1:-}" in
    --toggle)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        exit 0
        ;;
    --check)
        mute=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')
        echo "$mute"
        exit 0
        ;;
esac

mute=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')
if [ "$mute" = "yes" ]; then
    echo "Muted"
    exit 0
fi

# Get volume percentage and clean it up (ensure only numbers, even if it says "Full")
vol=$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | awk '/Volume/ {print $5; exit}' | tr -dc '0-9')

if [ -z "$vol" ]; then
    # Fallback to 100 if parsing failed but it wasn't muted (often happens at "Full")
    vol=$(pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | grep -q "100%" && echo "100" || echo "")
fi

[ -n "$vol" ] && printf '%s' "$vol"
