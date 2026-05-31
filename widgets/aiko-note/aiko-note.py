import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, Pango
import os
import sys

class AikoNote(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Note")
        
        # Identity for Hyprland rules
        self.set_role("aiko-note")
        self.set_wmclass("aiko-note", "aiko-note")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(350, 200)
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

        # Layout
        overlay = Gtk.Overlay()
        self.add(overlay)

        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        main_vbox.set_name("main-container")
        main_vbox.set_margin_top(15)
        main_vbox.set_margin_bottom(15)
        main_vbox.set_margin_start(20)
        main_vbox.set_margin_end(20)
        overlay.add(main_vbox)

        # Title
        title_label = Gtk.Label(label="Notes")
        title_label.set_name("note-title")
        title_label.set_halign(Gtk.Align.START)
        main_vbox.pack_start(title_label, False, False, 0)

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
        main_vbox.pack_start(scrolled, True, True, 5)

        # Cat icon (Bottom Right Overlay)
        # Using a custom SVG icon for better rendering control
        self.cat_image = Gtk.Image()
        self.cat_image.set_name("note-cat-icon")
        self.cat_image.set_halign(Gtk.Align.END)
        self.cat_image.set_valign(Gtk.Align.END)
        self.cat_image.set_margin_end(-10) # Overlap slightly for aesthetic
        self.cat_image.set_margin_bottom(-10)
        
        # Load SVG
        svg_path = self.get_asset_path("cat-icon.svg")
        if svg_path:
            # We use a Pixbuf to scale it properly
            try:
                from gi.repository import GdkPixbuf
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(svg_path, 100, 100, True)
                self.cat_image.set_from_pixbuf(pixbuf)
            except Exception as e:
                print(f"Failed to load SVG pixbuf: {e}")
        
        overlay.add_overlay(self.cat_image)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and self.is_composited():
            self.set_visual(visual)

        self.show_all()

    def get_asset_path(self, filename):
        # 1. Check local directory (dev)
        local_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", filename)
        if os.path.exists(local_path): return local_path
        
        # 2. Check installed path (scripts folder)
        installed_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", filename)
        if os.path.exists(installed_path): return installed_path

        # 3. Check flat installation path
        flat_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", filename)
        if os.path.exists(flat_path): return flat_path
        
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
        # Close on Escape
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        # Close on Ctrl+Q or Ctrl+W
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
