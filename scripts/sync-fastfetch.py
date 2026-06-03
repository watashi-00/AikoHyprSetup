#!/usr/bin/env python3
import os
import json
import re
import sys

def get_theme_color(waybar_dir):
    style_path = os.path.join(waybar_dir, "style.css")
    default_color = "#ff8fbd" # Pink Anime default
    if not os.path.exists(style_path):
        return default_color
    try:
        with open(style_path, 'r') as f:
            for line in f:
                if "@mako-border:" in line:
                    parts = line.split(":", 1)
                    if len(parts) > 1:
                        # Extract the color code, removing comments and whitespace
                        color = parts[1].split(';')[0].split('/*')[0].strip()
                        return color
    except:
        pass
    return default_color

def calculate_padding(ascii_path):
    if not os.path.exists(ascii_path):
        return 5
    try:
        with open(ascii_path, 'r') as f:
            lines = f.readlines()
        if not lines:
            return 5
        max_width = max(len(line.rstrip()) for line in lines)
        # We want at least 2 cells of gap. 
        # Fastfetch padding is added to the logo's width.
        if max_width > 50: return 2
        elif max_width > 40: return 3
        elif max_width > 30: return 4
        elif max_width > 20: return 6
        else: return 10
    except:
        return 5

def sync_fastfetch():
    config_dir = os.path.expanduser("~/.config/fastfetch")
    config_path = os.path.join(config_dir, "config.jsonc")
    waybar_dir = os.path.expanduser("~/.config/waybar")
    ascii_path = os.path.join(waybar_dir, "assets", "aiko-frame.txt")

    if not os.path.exists(config_path):
        print("Fastfetch config not found. Skipping sync.")
        return

    # Load JSONC
    try:
        with open(config_path, 'r') as f:
            content = f.read()
            
        clean_lines = []
        for line in content.split('\n'):
            if not re.match(r'^\s*//', line):
                clean_lines.append(line)
        
        clean_content = '\n'.join(clean_lines)
        clean_content = re.sub(r',\s*}', '}', clean_content)
        clean_content = re.sub(r',\s*\]', ']', clean_content)

        data = json.loads(clean_content)
    except Exception as e:
        print(f"Error reading fastfetch config: {e}")
        return

    # Ensure logo structure exists
    if "logo" not in data:
        data["logo"] = {}
    if "color" not in data["logo"]:
        data["logo"]["color"] = {}
    if "padding" not in data["logo"]:
        data["logo"]["padding"] = {}

    # Update Data
    color = get_theme_color(waybar_dir)
    padding = calculate_padding(ascii_path)

    data["logo"]["color"]["1"] = color
    data["logo"]["padding"]["left"] = padding
    data["logo"]["padding"]["right"] = 0

    # Save Config
    try:
        with open(config_path, 'w') as f:
            json.dump(data, f, indent=4)
        print(f"[fastfetch-sync] Updated logo padding to {padding} and color to {color}")
    except Exception as e:
        print(f"Error saving fastfetch config: {e}")

if __name__ == "__main__":
    sync_fastfetch()
