import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, Pango
import os
import sys

class AikoNote(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Note")
        
        # Identity for Hyprland rules
        self.set_name("aiko-note-window")
        self.set_role("aiko-note")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(True)
        self.set_default_size(350, 250)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        # File setup
        self.notes_file = os.path.expanduser("~/.cache/aiko-note.txt")
        os.makedirs(os.path.dirname(self.notes_file), exist_ok=True)
        if not os.path.exists(self.notes_file):
            with open(self.notes_file, "w") as f:
                f.write("Don't forget to drink water!\nStay hydrated, stay happy.")

        # CSS setup
        self.load_css()

        # Main Box (Transparent)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container - Renamed to avoid GObject property conflict
        self.styled_container = Gtk.Overlay()
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Content Box inside Overlay
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        content_vbox.set_margin_top(20)
        content_vbox.set_margin_bottom(20)
        content_vbox.set_margin_start(20)
        content_vbox.set_margin_end(20)
        self.styled_container.add(content_vbox)

        # Title
        title_label = Gtk.Label(label="Notes")
        title_label.set_name("note-title")
        title_label.set_halign(Gtk.Align.START)
        content_vbox.pack_start(title_label, False, False, 0)

        # Text View (Content)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_shadow_type(Gtk.ShadowType.NONE)
        
        self.textview = Gtk.TextView()
        self.textview.set_name("note-content")
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.set_accepts_tab(True)
        
        self.buffer = self.textview.get_buffer()
        try:
            with open(self.notes_file, "r") as f:
                self.buffer.set_text(f.read())
        except Exception:
            self.buffer.set_text("")
        
        self.buffer.connect("changed", self.on_text_changed)
        scrolled.add(self.textview)
        content_vbox.pack_start(scrolled, True, True, 5)

        # Cat icon (Bottom Right Overlay)
        self.cat_image = Gtk.Image()
        self.cat_image.set_name("note-cat-icon")
        self.cat_image.set_halign(Gtk.Align.END)
        self.cat_image.set_valign(Gtk.Align.END)
        self.cat_image.set_margin_end(-5)
        self.cat_image.set_margin_bottom(-5)
        
        self.update_cat_icon()
        self.styled_container.add_overlay(self.cat_image)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def update_cat_icon(self):
        svg_path = self.get_asset_path("cat-icon.svg")
        if not svg_path: return

        context = self.cat_image.get_style_context()
        found, color = context.lookup_color("accent_color")
        if not found:
            color = Gdk.RGBA()
            color.parse("#ff8fbd")
        
        # Accessing components safely
        try:
            r, g, b = color.red, color.green, color.blue
            hex_color = "#{:02x}{:02x}{:02x}".format(
                int(r * 255),
                int(g * 255),
                int(b * 255)
            )
        except Exception:
            hex_color = "#ff8fbd"

        try:
            with open(svg_path, "r") as f:
                svg_data = f.read()
            
            import re
            svg_data = re.sub(r'fill:#[0-9a-fA-F]{6}', f'fill:{hex_color}', svg_data)
            svg_data = re.sub(r'stroke:#[0-9a-fA-F]{6}', f'stroke:{hex_color}', svg_data)
            svg_data = re.sub(r'fill="#[0-9a-fA-F]{6}"', f'fill="{hex_color}"', svg_data)
            svg_data = re.sub(r'stroke="#[0-9a-fA-F]{6}"', f'stroke="{hex_color}"', svg_data)
            svg_data = svg_data.replace("currentColor", hex_color)
            
            from gi.repository import GdkPixbuf
            loader = GdkPixbuf.PixbufLoader.new_with_type("svg")
            loader.write(svg_data.encode('utf-8'))
            loader.close()
            
            pixbuf = loader.get_pixbuf()
            target_h = 120
            aspect = pixbuf.get_width() / pixbuf.get_height()
            target_w = int(target_h * aspect)
            
            scaled_pixbuf = pixbuf.scale_simple(target_w, target_h, GdkPixbuf.InterpType.BILINEAR)
            self.cat_image.set_from_pixbuf(scaled_pixbuf)
        except Exception as e:
            print(f"Error coloring/scaling SVG: {e}")

    def get_asset_path(self, filename):
        local_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", filename)
        if os.path.exists(local_path): return local_path
        installed_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", filename)
        if os.path.exists(installed_path): return installed_path
        return None

    def load_css(self):
        css_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme.css")
        if os.path.exists(css_path):
            provider = Gtk.CssProvider()
            provider.load_from_path(css_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def on_text_changed(self, buffer):
        text = buffer.get_text(buffer.get_start_iter(), buffer.get_end_iter(), True)
        try:
            with open(self.notes_file, "w") as f:
                f.write(text)
        except Exception as e:
            print(f"Error saving note: {e}")

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        if (event.state & Gdk.ModifierType.CONTROL_MASK):
            if event.keyval == Gdk.KEY_q or event.keyval == Gdk.KEY_w:
                self.destroy()

if __name__ == "__main__":
    try:
        AikoNote()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoNote: {e}")
        sys.exit(1)
