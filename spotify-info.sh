#!/usr/bin/env bash
# Output: artist - title or empty (robust for different playerctl outputs)
metadata=$(playerctl metadata 2> /dev/null)
if [ -z "$metadata" ]; then
	exit 0
fi
artist=$(echo "$metadata" | sed -n "s/^xesam:artist\s*\(.*\)/\1/p" | sed -n '1p')
title=$(echo "$metadata" | sed -n "s/^xesam:title\s*\(.*\)/\1/p" | sed -n '1p')
if [ -z "$artist" ] && [ -z "$title" ]; then
	# fallback simple format
	playerctl metadata --format '{{artist}} - {{title}}' 2> /dev/null
	exit 0
fi
artist=$(echo "$artist" | sed 's/^\s\+//;s/\s\+$//')
title=$(echo "$title" | sed 's/^\s\+//;s/\s\+$//')
echo "$artist - $title"
