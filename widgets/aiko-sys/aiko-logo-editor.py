import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os
import json
import re

class AikoLogoEditor(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Terminal Logo Editor")
        
        self.set_name("aiko-logo-editor")
        self.set_default_size(500, 600)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)

        # Paths
        self.config_dir = os.path.expanduser("~/.config/fastfetch")
        self.config_path = os.path.join(self.config_dir, "config.jsonc")
        self.assets_dir = os.path.expanduser("~/.config/waybar/assets")
        self.ascii_path = os.path.join(self.assets_dir, "aiko-frame.txt")
        
        # Load Fastfetch Config (handling JSONC comments)
        self.config_data = self.load_fastfetch_config()

        # Get dynamic theme color
        self.accent = self.get_active_accent_color()

        # Load CSS
        self.load_css()

        # Layout
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        self.vbox.set_margin_top(40)
        self.vbox.set_margin_bottom(40)
        self.vbox.set_margin_start(40)
        self.vbox.set_margin_end(40)
        self.add(self.vbox)

        # Header
        header_lbl = Gtk.Label()
        header_lbl.set_markup(f"<span size='xx-large' weight='bold' foreground='{self.accent}'>Terminal Logo Settings</span>")
        self.vbox.pack_start(header_lbl, False, False, 0)

        # ASCII Text Area
        ascii_lbl = Gtk.Label(label="ASCII Art")
        ascii_lbl.set_halign(Gtk.Align.START)
        self.vbox.pack_start(ascii_lbl, False, False, 0)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)
        scrolled.set_shadow_type(Gtk.ShadowType.IN)
        scrolled.set_min_content_height(250)
        self.vbox.pack_start(scrolled, True, True, 0)

        self.ascii_view = Gtk.TextView()
        self.ascii_view.set_monospace(True)
        self.ascii_buffer = self.ascii_view.get_buffer()
        # Load current ASCII content
        self.load_ascii_content()
        scrolled.add(self.ascii_view)

        # Color Selection Row
        color_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        self.vbox.pack_start(color_hbox, False, False, 0)

        color_lbl = Gtk.Label(label="Logo Color")
        color_lbl.set_halign(Gtk.Align.START)
        color_hbox.pack_start(color_lbl, True, True, 0)

        self.color_button = Gtk.ColorButton()
        # Default to magenta if not set
        current_color = self.get_current_logo_color()
        rgba = Gdk.RGBA()
        rgba.parse(current_color)
        self.color_button.set_rgba(rgba)
        color_hbox.pack_end(self.color_button, False, False, 0)

        # Auto-spacing Info
        spacing_info = Gtk.Label()
        spacing_info.set_markup("<span size='small' font_style='italic'>Horizontal spacing is automatically calculated\nbased on the width of your ASCII art.</span>")
        spacing_info.set_justify(Gtk.Justification.CENTER)
        self.vbox.pack_start(spacing_info, False, False, 0)

        # Buttons
        actions_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.vbox.pack_start(actions_hbox, False, False, 0)

        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", Gtk.main_quit)
        actions_hbox.pack_start(cancel_btn, True, True, 0)

        save_btn = Gtk.Button(label="Apply & Save")
        save_btn.set_name("save-button")
        save_btn.connect("clicked", self.on_save)
        actions_hbox.pack_start(save_btn, True, True, 0)

        self.connect("destroy", Gtk.main_quit)
        self.show_all()

    def load_fastfetch_config(self):
        if not os.path.exists(self.config_path):
            return {}
        try:
            with open(self.config_path, 'r') as f:
                content = f.read()
                
            # Remove comments (// ...) but be careful not to remove URLs in quotes
            # A simpler approach: just remove lines that start with // or spaces + //
            clean_lines = []
            for line in content.split('\n'):
                if not re.match(r'^\s*//', line):
                    clean_lines.append(line)
            
            clean_content = '\n'.join(clean_lines)
            
            # Remove trailing commas which are invalid in strict JSON
            clean_content = re.sub(r',\s*}', '}', clean_content)
            clean_content = re.sub(r',\s*\]', ']', clean_content)

            return json.loads(clean_content)
        except Exception as e:
            # Silently fallback to an empty dict if parsing fails to avoid console spam
            # Fastfetch configs can be complex JSONC. The script will recreate necessary structures.
            return {}

    def load_ascii_content(self):
        if os.path.exists(self.ascii_path):
            try:
                with open(self.ascii_path, 'r') as f:
                    content = f.read()
                    self.ascii_buffer.set_text(content)
            except Exception as e:
                print(f"Error loading ASCII: {e}")

    def get_current_logo_color(self):
        # Fastfetch ASCII colors are usually in logo.color.1
        try:
            return self.config_data.get("logo", {}).get("color", {}).get("1", "magenta")
        except:
            return "magenta"

    def calculate_ideal_padding(self, content=None):
        if content:
            lines = content.splitlines()
        elif os.path.exists(self.ascii_path):
            try:
                with open(self.ascii_path, 'r') as f:
                    lines = f.readlines()
            except:
                return 10
        else:
            return 10

        if not lines:
            return 10
            
        max_width = max(len(line.rstrip()) for line in lines)
        
        # Logic: bigger logo -> smaller padding
        if max_width > 50:
            return 0
        elif max_width > 40:
            return 2
        elif max_width > 30:
            return 4
        elif max_width > 20:
            return 8
        else:
            return 12

    def on_save(self, btn):
        # Get ASCII content from text area
        start_iter = self.ascii_buffer.get_start_iter()
        end_iter = self.ascii_buffer.get_end_iter()
        ascii_content = self.ascii_buffer.get_text(start_iter, end_iter, True)

        # Save ASCII file
        try:
            with open(self.ascii_path, 'w') as f:
                f.write(ascii_content)
        except Exception as e:
            print(f"Error saving ASCII file: {e}")

        rgba = self.color_button.get_rgba()
        hex_color = "#{:02x}{:02x}{:02x}".format(
            int(rgba.red * 255),
            int(rgba.green * 255),
            int(rgba.blue * 255)
        )

        # Ensure logo structure exists
        if "logo" not in self.config_data:
            self.config_data["logo"] = {}
        
        # Set source to our custom ASCII file
        self.config_data["logo"]["source"] = self.ascii_path

        # Set color
        if "color" not in self.config_data["logo"]:
            self.config_data["logo"]["color"] = {}
        self.config_data["logo"]["color"]["1"] = hex_color

        # Calculate and set padding
        if "padding" not in self.config_data["logo"]:
            self.config_data["logo"]["padding"] = {}
        
        ideal_padding = self.calculate_ideal_padding(ascii_content)
        self.config_data["logo"]["padding"]["left"] = ideal_padding

        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.config_data, f, indent=4)
            print(f"Saved logo settings: Source={self.ascii_path}, Color={hex_color}, Padding={ideal_padding}")
            Gtk.main_quit()
        except Exception as e:
            print(f"Error saving fastfetch config: {e}")

    def get_active_accent_color(self):
        default_color = "#ff8fbd"
        try:
            style_path = os.path.expanduser("~/.config/waybar/style.css")
            if os.path.exists(style_path):
                with open(style_path, "r") as f:
                    content = f.read()
                    import re
                    match = re.search(r"@waybar_accent:\s*(#[0-9a-fA-F]{6})", content)
                    if match:
                        return match.group(1)
        except Exception:
            pass
        return default_color

    def hex_to_rgba(self, hex_color, alpha=1.0):
        hex_color = hex_color.lstrip('#')
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return f"rgba({r},{g},{b},{alpha})"

    def load_css(self):
        accent = self.accent
        hover_color = self.hex_to_rgba(accent, 0.2)
        save_hover = self.hex_to_rgba(accent, 0.8)
        colorbutton_border = self.hex_to_rgba(accent, 0.5)

        css_provider = Gtk.CssProvider()
        css = f"""
            window {{ background-color: #1e2023; color: #e6e1ea; }}
            textview, textview text {{ 
                font-family: "JetBrainsMono Nerd Font"; 
                background-color: #181a1d; 
                background-image: none;
                color: {accent};
                padding: 10px;
            }}
            button {{ 
                background-color: rgba(255,255,255,0.05); 
                color: #e6e1ea; 
                border-radius: 8px; 
                padding: 10px;
            }}
            button:hover {{ background-color: {hover_color}; }}
            #save-button {{ 
                background-color: {accent}; 
                color: #1e2023; 
                font-weight: bold; 
            }}
            #save-button:hover {{ background-color: {save_hover}; }}
            label {{ font-family: "JetBrainsMono Nerd Font"; }}
            colorbutton {{ 
                border-radius: 8px; 
                border: 1px solid {colorbutton_border};
            }}
        """
        css_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

if __name__ == "__main__":
    AikoLogoEditor()
    Gtk.main()
