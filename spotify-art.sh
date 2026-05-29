#!/usr/bin/env bash
artUrl=$(playerctl metadata mpris:artUrl 2> /dev/null)

if [ -z "$artUrl" ]; then
    echo ""
    exit 0
fi

filename="/tmp/spotify_cover.png"
lastUrlFile="/tmp/spotify_cover_url.txt"
lastUrl=$(cat "$lastUrlFile" 2> /dev/null || echo "")

# Support file:// paths and http(s) URLs
if [[ "$artUrl" == file://* ]]; then
    # strip file://
    filepath="${artUrl#file://}"
    if [ -f "$filepath" ]; then
        cp "$filepath" "$filename" 2> /dev/null || true
        echo "$artUrl" > "$lastUrlFile"
        echo "$filename"
        exit 0
    fi
fi

if [ "$artUrl" != "$lastUrl" ]; then
    # try download, fall back to leaving previous file
    curl -s -L "$artUrl" -o "$filename" || true
    echo "$artUrl" > "$lastUrlFile"
fi

if [ -f "$filename" ]; then
    echo "$filename"
else
    echo ""
fi
