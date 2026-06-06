#!/usr/bin/env python3
import sys
import os
import re
import colorsys
import json
import subprocess
from PIL import Image

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip('#')
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(int(rgb[0]), int(rgb[1]), int(rgb[2]))

def extract_video_frame(video_path):
    frame_path = "/tmp/aiko_wall_frame.jpg"
    
    # If it's a directory (e.g. Wallpaper Engine project directory)
    if os.path.isdir(video_path):
        preview_files = ["preview.jpg", "preview.png", "preview.gif", "preview.jpeg"]
        for pf in preview_files:
            p_path = os.path.join(video_path, pf)
            if os.path.exists(p_path):
                return p_path
        
        project_json = os.path.join(video_path, "project.json")
        if os.path.exists(project_json):
            try:
                with open(project_json, 'r') as f:
                    proj_data = json.load(f)
                file_name = proj_data.get("file")
                if file_name:
                    p_path = os.path.join(video_path, file_name)
                    if os.path.exists(p_path) and os.path.isfile(p_path):
                        video_path = p_path
            except Exception:
                pass

    if not os.path.isfile(video_path):
        return video_path

    # Check if the file is an animated gif or video
    ext = os.path.splitext(video_path)[1].lower()
    if ext in [".gif", ".mp4", ".mkv", ".webm", ".avi", ".mov"]:
        try:
            # Extract frame at 1s mark using ffmpeg
            cmd = ["ffmpeg", "-y", "-ss", "00:00:01", "-i", video_path, "-vframes", "1", "-q:v", "2", frame_path]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            if os.path.exists(frame_path):
                return frame_path
        except Exception:
            pass
            
    return video_path

def extract_colors(image_path):
    if not os.path.exists(image_path) or not os.path.isfile(image_path):
        return None
    try:
        img = Image.open(image_path)
        img = img.resize((150, 150))
        colors = img.getcolors(30000)
        if not colors:
            return None
        colors.sort(key=lambda x: x[0], reverse=True)
        
        parsed_colors = []
        for count, rgb in colors:
            if len(rgb) < 3: continue
            r, g, b = rgb[:3]
            h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            parsed_colors.append({
                "rgb": (r, g, b),
                "hsv": (h, s, v),
                "count": count
            })
        return parsed_colors
    except Exception:
        return None

def generate_palette(parsed_colors):
    # Default fallbacks (Pink Anime theme colors)
    accent_rgb = (255, 143, 189)
    sub_accent_rgb = (203, 166, 247)
    bg_rgb = (30, 32, 35)
    text_rgb = (230, 225, 234)
    
    if parsed_colors:
        # 1. Primary Accent: Look for a vibrant color with high saturation and medium/high value
        max_score = -1
        for c in parsed_colors:
            r, g, b = c["rgb"]
            h, s, v = c["hsv"]
            # Saturation >= 30%, Brightness >= 40%
            if 0.30 <= s <= 0.95 and 0.40 <= v <= 0.95:
                score = c["count"] * s
                if score > max_score:
                    max_score = score
                    accent_rgb = (r, g, b)
                    
        # 2. Secondary Accent: Slightly hue-shifted or second most vibrant
        h_acc, s_acc, v_acc = colorsys.rgb_to_hsv(accent_rgb[0]/255.0, accent_rgb[1]/255.0, accent_rgb[2]/255.0)
        sub_acc = colorsys.hsv_to_rgb((h_acc + 0.15) % 1.0, s_acc, v_acc)
        sub_accent_rgb = (int(sub_acc[0]*255), int(sub_acc[1]*255), int(sub_acc[2]*255))
        
        # 3. Background: Deeply tinted background based on accent's hue
        bg = colorsys.hsv_to_rgb(h_acc, 0.15, 0.08)
        bg_rgb = (int(bg[0]*255), int(bg[1]*255), int(bg[2]*255))
        
        # 4. Text: Extremely bright tinted color
        txt = colorsys.hsv_to_rgb(h_acc, 0.06, 0.95)
        text_rgb = (int(txt[0]*255), int(txt[1]*255), int(txt[2]*255))

    accent_hex = '{:02x}{:02x}{:02x}'.format(accent_rgb[0], accent_rgb[1], accent_rgb[2])
    sub_accent_hex = '{:02x}{:02x}{:02x}'.format(sub_accent_rgb[0], sub_accent_rgb[1], sub_accent_rgb[2])
    bg_hex = '{:02x}{:02x}{:02x}'.format(bg_rgb[0], bg_rgb[1], bg_rgb[2])
    text_hex = '{:02x}{:02x}{:02x}'.format(text_rgb[0], text_rgb[1], text_rgb[2])

    return {
        "ACCENT": f"#{accent_hex}",
        "ACCENT_HEX": accent_hex,
        "ACCENT_HEX_ALPHA": f"{accent_hex}ff",
        "ACCENT_RGB": f"{accent_rgb[0]}, {accent_rgb[1]}, {accent_rgb[2]}",
        "SUB_ACCENT": f"#{sub_accent_hex}",
        "SUB_ACCENT_HEX": sub_accent_hex,
        "SUB_ACCENT_HEX_ALPHA": f"{sub_accent_hex}ff",
        "SUB_ACCENT_RGB": f"{sub_accent_rgb[0]}, {sub_accent_rgb[1]}, {sub_accent_rgb[2]}",
        "BG": f"#{bg_hex}",
        "BG_HEX": bg_hex,
        "BG_RGB": f"{bg_rgb[0]}, {bg_rgb[1]}, {bg_rgb[2]}",
        "TEXT": f"#{text_hex}",
        "TEXT_HEX": text_hex,
        "TEXT_RGB": f"{text_rgb[0]}, {text_rgb[1]}, {text_rgb[2]}"
    }

def create_template_if_needed(source_path, template_path):
    if os.path.exists(template_path) or not os.path.exists(source_path):
        return
    try:
        with open(source_path, 'r', errors='ignore') as f:
            content = f.read()
        
        # Map variables
        content = content.replace("pink-anime.css", "dynamic-wall.css")
        content = content.replace("Pink Anime", "Dynamic Wallpaper")
        content = content.replace("rgba(30, 32, 35, 0.95)", "rgba({{BG_RGB}}, 0.95)")
        content = content.replace("rgba(255, 134, 185, 0.28)", "rgba({{ACCENT_RGB}}, 0.3)")
        
        # Exact color replacements with hashes
        content = content.replace("#ff8fbd", "{{ACCENT}}")
        content = content.replace("#ffd7e8", "{{TEXT}}")
        content = content.replace("#1e2023", "{{BG}}")
        content = content.replace("#1E2023", "{{BG}}")
        content = content.replace("#f5b9d4", "{{ACCENT}}")
        content = content.replace("#cba6f7", "{{SUB_ACCENT}}")
        
        # Hyprland active border variables without hashes (including 'rgba(' wrapping check)
        content = content.replace("rgba(f5c2e7ff)", "rgba({{ACCENT_HEX_ALPHA}})")
        content = content.replace("rgba(cba6f7ff)", "rgba({{SUB_ACCENT_HEX_ALPHA}})")
        
        with open(template_path, 'w') as f:
            f.write(content)
    except Exception:
        pass

def compile_template(template_path, output_path, palette):
    if not os.path.exists(template_path):
        return
    try:
        with open(template_path, 'r', errors='ignore') as f:
            content = f.read()
        
        for key, val in palette.items():
            content = content.replace(f"{{{{{key}}}}}", val)
            
        with open(output_path, 'w') as f:
            f.write(content)
    except Exception:
        pass

def main():
    if len(sys.argv) < 2:
        print("Usage: aiko-wall-sync.py <wallpaper_path>")
        sys.exit(1)
        
    wall_path = sys.argv[1]
    
    # Resolve roots
    script_dir = os.path.dirname(os.path.abspath(__file__))
    aiko_root = os.path.dirname(script_dir)
    themes_dir = os.path.join(aiko_root, "themes")
    widgets_dir = os.path.join(aiko_root, "widgets")
    
    # Process wallpaper source (frame extraction if video/gif)
    target_img = extract_video_frame(wall_path)
    
    # Extract palette
    colors = extract_colors(target_img)
    palette = generate_palette(colors)
    
    # 1. Rebuild Waybar Global Theme
    pink_theme = os.path.join(themes_dir, "pink-anime.css")
    template_theme = os.path.join(themes_dir, "dynamic-wall.template.css")
    output_theme = os.path.join(themes_dir, "dynamic-wall.css")
    
    create_template_if_needed(pink_theme, template_theme)
    compile_template(template_theme, output_theme, palette)
    
    # 2. Rebuild Widget Themes
    if os.path.exists(widgets_dir):
        for widget in os.listdir(widgets_dir):
            w_dir = os.path.join(widgets_dir, widget)
            w_themes = os.path.join(w_dir, "themes")
            if os.path.isdir(w_themes):
                pink_w = os.path.join(w_themes, "pink-anime.css")
                template_w = os.path.join(w_themes, "dynamic-wall.template.css")
                output_w = os.path.join(w_themes, "dynamic-wall.css")
                
                create_template_if_needed(pink_w, template_w)
                compile_template(template_w, output_w, palette)

    # 3. Invoke theme-selector.sh to compile and sync dynamic-wall globally
    selector_script = os.path.join(script_dir, "theme-selector.sh")
    if os.path.exists(selector_script):
        subprocess.run(["bash", selector_script, "dynamic-wall"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    main()
