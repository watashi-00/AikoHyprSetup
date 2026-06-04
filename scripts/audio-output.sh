#!/usr/bin/env bash
set -e

if ! command -v pactl >/dev/null 2>&1; then
    exit 0
fi

case "${1:-}" in
    --toggle)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        exit 0
        ;;
    --check)
        mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
        echo "$mute"
        exit 0
        ;;
esac

mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
if [ "$mute" = "yes" ]; then
    echo "Muted"
    exit 0
fi

vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '/Volume/ {print $5; exit}' | tr -d '%')
if [ -z "$vol" ]; then
    exit 0
fi
printf '%s%%' "$vol"
