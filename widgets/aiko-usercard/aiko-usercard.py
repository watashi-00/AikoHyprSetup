import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango, GdkPixbuf
import os
import sys
import json
import cairo

class AikoUserCard(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko User Card")
        
        # Identity for Hyprland rules
        self.set_name("aiko-usercard-window")
        self.set_role("aiko-usercard")
        self.set_wmclass("aiko-usercard", "aiko-usercard")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(420, 320)

        # Base paths
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.project_root = os.path.abspath(os.path.join(self.script_dir, "../../"))
        
        self.config = self.load_config()
        self.load_css()

        # Main Box (Transparent)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Content Box inside Container
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        content_vbox.set_margin_top(25)
        content_vbox.set_margin_bottom(25)
        content_vbox.set_margin_start(25)
        content_vbox.set_margin_end(25)
        self.styled_container.pack_start(content_vbox, True, True, 0)

        # Top Section (Avatar + Info)
        self.main_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=25)
        content_vbox.pack_start(self.main_hbox, False, False, 0)

        # Left Side: Avatar
        self.avatar_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.avatar_box.set_size_request(110, 110)
        self.main_hbox.pack_start(self.avatar_box, False, False, 0)
        
        avatar_path = os.path.join(self.project_root, self.config.get("avatar", "assets/aiko-icon.svg"))
        if not os.path.exists(avatar_path):
            avatar_path = os.path.join(self.script_dir, "../../assets/aiko-icon.svg")

        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(avatar_path, 110, 110, True)
            circular_pixbuf = self.get_circular_pixbuf(pixbuf)
            self.avatar_image = Gtk.Image.new_from_pixbuf(circular_pixbuf)
            self.avatar_image.set_name("usercard-avatar")
            
            avatar_event = Gtk.EventBox()
            avatar_event.set_name("usercard-avatar-container")
            avatar_event.add(self.avatar_image)
            self.avatar_box.pack_start(avatar_event, False, False, 0)
        except Exception as e:
            print(f"Error loading avatar: {e}")

        # Right Side: Info
        self.info_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.main_hbox.pack_start(self.info_vbox, True, True, 0)

        self.name_label = Gtk.Label(label=self.config.get("name", "User"))
        self.name_label.set_name("usercard-name")
        self.name_label.set_halign(Gtk.Align.START)
        self.info_vbox.pack_start(self.name_label, False, False, 0)

        self.handle_label = Gtk.Label(label=self.config.get("handle", "@user"))
        self.handle_label.set_name("usercard-handle")
        self.handle_label.set_halign(Gtk.Align.START)
        self.info_vbox.pack_start(self.handle_label, False, False, 0)

        tags_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        self.info_vbox.pack_start(tags_hbox, False, False, 5)

        self.tag_label = Gtk.Label(label=f"»  {self.config.get('tag', 'linux')}")
        self.tag_label.set_name("usercard-tag")
        tags_hbox.pack_start(self.tag_label, False, False, 0)

        self.country_label = Gtk.Label(label=f"  {self.config.get('country', 'us')}")
        self.country_label.set_name("usercard-country")
        tags_hbox.pack_start(self.country_label, False, False, 0)

        # Quote Box
        self.quote_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.quote_container.set_name("usercard-quote-box")
        self.info_vbox.pack_start(self.quote_container, True, True, 5)

        quote_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        quote_hbox.set_margin_top(12)
        quote_hbox.set_margin_bottom(12)
        quote_hbox.set_margin_start(15)
        quote_hbox.set_margin_end(15)
        self.quote_container.add(quote_hbox)

        self.quote_text = Gtk.Label(label=self.config.get("quote", "Hello World!"))
        self.quote_text.set_name("usercard-quote-text")
        self.quote_text.set_line_wrap(True)
        self.quote_text.set_max_width_chars(25)
        self.quote_text.set_halign(Gtk.Align.START)
        quote_hbox.pack_start(self.quote_text, True, True, 0)

        self.quote_icon = Gtk.Label(label=self.config.get("quote_icon", "♥"))
        self.quote_icon.set_name("usercard-quote-icon")
        self.quote_icon.set_valign(Gtk.Align.END)
        quote_hbox.pack_end(self.quote_icon, False, False, 0)

        # Bottom Section
        config_tags = self.config.get("tags", [])
        if config_tags:
            self.tags_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10, homogeneous=True)
            content_vbox.pack_end(self.tags_row, False, False, 0)

            for tag_text in config_tags:
                tag_lbl = Gtk.Label(label=tag_text)
                tag_lbl.set_name("usercard-bottom-tag")
                tag_eb = Gtk.EventBox()
                tag_eb.set_name("usercard-bottom-tag-container")
                tag_eb.add(tag_lbl)
                self.tags_row.pack_start(tag_eb, True, True, 0)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def get_circular_pixbuf(self, pixbuf):
        if not pixbuf: return None
        width = pixbuf.get_width()
        height = pixbuf.get_height()
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
        context = cairo.Context(surface)
        radius = min(width, height) / 2
        context.arc(width / 2, height / 2, radius, 0, 2 * 3.14159)
        context.clip()
        Gdk.cairo_set_source_pixbuf(context, pixbuf, 0, 0)
        context.paint()
        return Gdk.pixbuf_get_from_surface(surface, 0, 0, width, height)

    def load_config(self):
        config_path = os.path.join(self.script_dir, "usercard.json")
        if os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Error loading usercard config: {e}")
        return {}

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        theme_path = os.path.join(self.script_dir, "theme.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    try:
        AikoUserCard()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoUserCard: {e}")
        sys.exit(1)
