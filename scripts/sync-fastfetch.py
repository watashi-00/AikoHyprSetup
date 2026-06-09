#!/usr/bin/env python3
import os
import json
import re
import sys
import colorsys

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip("#")
    try:
        return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))
    except:
        return (255, 143, 189) # Fallback

def rgb_to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*(int(c) for c in rgb))

def generate_palette(accent_hex):
    r, g, b = hex_to_rgb(accent_hex)
    h, l, s = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
    palette = []
    for i in range(8):
        hi = (h + i * 0.125) % 1.0
        # Keep lightness and saturation high/pastel
        li = max(0.5, min(l, 0.8))
        si = max(0.6, s)
        ri, gi, bi = colorsys.hls_to_rgb(hi, li, si)
        palette.append(rgb_to_hex((ri*255, gi*255, bi*255)))
    return palette

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
    
    # Check if we are using the default logo or a custom one
    source = data.get("logo", {}).get("source", "auto")
    
    if source == "auto":
        padding = 2 # Default padding for distro logos
        data["logo"]["color"]["1"] = color
    else:
        padding = calculate_padding(ascii_path)
        # Preserve user-configured custom logo color (from --edit-logo)
        if "color" not in data["logo"]:
            data["logo"]["color"] = {}
        if "1" not in data["logo"]["color"]:
            data["logo"]["color"]["1"] = color

    data["logo"]["padding"]["left"] = padding
    data["logo"]["padding"]["right"] = 0

    # Dynamic palette generation and injection
    palette = generate_palette(color)
    format_str = "".join(f"{{##{c.lstrip('#')}}}████" for c in palette)
    if "modules" in data:
        for module in data["modules"]:
            if isinstance(module, dict) and module.get("type") == "custom" and "████" in module.get("format", ""):
                module["format"] = format_str

    # Save Config
    try:
        with open(config_path, 'w') as f:
            json.dump(data, f, indent=4)
        print(f"[fastfetch-sync] Updated logo padding to {padding}, color to {color} and custom colors palette")
    except Exception as e:
        print(f"Error saving fastfetch config: {e}")

if __name__ == "__main__":
    sync_fastfetch()
