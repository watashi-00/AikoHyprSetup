import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf
import os
import json
import cairo

class AikoUserCardEditor(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko User Card Editor")
        
        self.set_name("aiko-usercard-editor")
        self.set_default_size(500, 600)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)

        # Paths
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.config_path = os.path.join(self.script_dir, "usercard.json")
        self.project_root = os.path.abspath(os.path.join(self.script_dir, "../../"))
        
        # Load Data
        self.data = self.load_config()

        # Load CSS
        self.load_css()

        # Layout
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        self.vbox.set_margin_top(30)
        self.vbox.set_margin_bottom(30)
        self.vbox.set_margin_start(30)
        self.vbox.set_margin_end(30)
        self.add(self.vbox)

        # Header
        header_lbl = Gtk.Label()
        header_lbl.set_markup("<span size='xx-large' weight='bold' foreground='#ff8fbd'>User Card Settings</span>")
        self.vbox.pack_start(header_lbl, False, False, 0)

        # Scrollable Area for Form
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.vbox.pack_start(scrolled, True, True, 0)

        form_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        scrolled.add(form_vbox)

        # Avatar Selection
        avatar_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        form_vbox.pack_start(avatar_hbox, False, False, 0)
        
        self.avatar_preview = Gtk.Image()
        self.update_avatar_preview(self.data.get("avatar", "assets/aiko-icon.svg"))
        avatar_hbox.pack_start(self.avatar_preview, False, False, 0)

        avatar_btn = Gtk.Button(label="Choose Avatar")
        avatar_btn.connect("clicked", self.on_avatar_browse)
        avatar_hbox.pack_start(avatar_btn, True, False, 0)

        # Fields
        self.name_entry = self.create_field(form_vbox, "Display Name", self.data.get("name", ""))
        self.handle_entry = self.create_field(form_vbox, "Handle (@username)", self.data.get("handle", ""))
        self.tag_entry = self.create_field(form_vbox, "System/Tag (e.g. hyprland)", self.data.get("tag", ""))
        self.country_entry = self.create_field(form_vbox, "Country Code (e.g. us, br)", self.data.get("country", ""))
        self.quote_entry = self.create_field(form_vbox, "Quote", self.data.get("quote", ""))

        # Bottom Tags
        tags_lbl = Gtk.Label(label="Bottom Tags (comma separated)")
        tags_lbl.set_halign(Gtk.Align.START)
        form_vbox.pack_start(tags_lbl, False, False, 0)
        
        self.tags_entry = Gtk.Entry()
        self.tags_entry.set_text(", ".join(self.data.get("tags", [])))
        form_vbox.pack_start(self.tags_entry, False, False, 0)

        # Buttons
        actions_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.vbox.pack_start(actions_hbox, False, False, 0)

        cancel_btn = Gtk.Button(label="Cancel")
        cancel_btn.connect("clicked", Gtk.main_quit)
        actions_hbox.pack_start(cancel_btn, True, True, 0)

        save_btn = Gtk.Button(label="Save Changes")
        save_btn.set_name("save-button")
        save_btn.connect("clicked", self.on_save)
        actions_hbox.pack_start(save_btn, True, True, 0)

        self.connect("destroy", Gtk.main_quit)
        self.show_all()

    def create_field(self, container, label_text, default_value):
        lbl = Gtk.Label(label=label_text)
        lbl.set_halign(Gtk.Align.START)
        container.pack_start(lbl, False, False, 0)
        
        entry = Gtk.Entry()
        entry.set_text(default_value)
        container.pack_start(entry, False, False, 0)
        return entry

    def get_circular_pixbuf(self, pixbuf):
        if not pixbuf: return None
        width = pixbuf.get_width()
        height = pixbuf.get_height()
        
        surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, width, height)
        context = cairo.Context(surface)
        
        # Circle path
        radius = min(width, height) / 2
        context.arc(width / 2, height / 2, radius, 0, 2 * 3.14159)
        context.clip()
        
        Gdk.cairo_set_source_pixbuf(context, pixbuf, 0, 0)
        context.paint()
        
        return Gdk.pixbuf_get_from_surface(surface, 0, 0, width, height)

    def update_avatar_preview(self, rel_path):
        full_path = os.path.join(self.project_root, rel_path)
        if not os.path.exists(full_path):
            full_path = os.path.join(self.script_dir, "../../assets/aiko-icon.svg")
        
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(full_path, 80, 80, True)
            circular = self.get_circular_pixbuf(pixbuf)
            if circular:
                self.avatar_preview.set_from_pixbuf(circular)
            else:
                self.avatar_preview.set_from_pixbuf(pixbuf)
        except: pass

    def on_avatar_browse(self, btn):
        dialog = Gtk.FileChooserDialog(
            title="Select Avatar Image",
            parent=self,
            action=Gtk.FileChooserAction.OPEN
        )
        dialog.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OPEN, Gtk.ResponseType.OK)
        
        filter_img = Gtk.FileFilter()
        filter_img.set_name("Images")
        filter_img.add_mime_type("image/png")
        filter_img.add_mime_type("image/jpeg")
        filter_img.add_mime_type("image/svg+xml")
        dialog.add_filter(filter_img)

        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            selected_path = dialog.get_filename()
            # Try to make it relative to project root if possible
            if selected_path.startswith(self.project_root):
                self.data["avatar"] = os.path.relpath(selected_path, self.project_root)
            else:
                self.data["avatar"] = selected_path
            self.update_avatar_preview(self.data["avatar"])
        
        dialog.destroy()

    def on_save(self, btn):
        self.data["name"] = self.name_entry.get_text()
        self.data["handle"] = self.handle_entry.get_text()
        self.data["tag"] = self.tag_entry.get_text()
        self.data["country"] = self.country_entry.get_text()
        self.data["quote"] = self.quote_entry.get_text()
        
        raw_tags = self.tags_entry.get_text().split(",")
        self.data["tags"] = [t.strip() for t in raw_tags if t.strip()]

        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.data, f, indent=4)
            print("Configuration saved successfully.")
            Gtk.main_quit()
        except Exception as e:
            print(f"Error saving config: {e}")

    def load_config(self):
        if os.path.exists(self.config_path):
            with open(self.config_path, 'r') as f:
                return json.load(f)
        return {}

    def load_css(self):
        css_provider = Gtk.CssProvider()
        css = """
            window { background-color: #1e2023; color: #e6e1ea; }
            entry { 
                background-color: rgba(255,255,255,0.05); 
                background-image: none;
                color: white; 
                border: 1px solid rgba(255,143,189,0.3);
                border-radius: 5px;
                padding: 8px;
            }
            button { 
                background-color: rgba(255,255,255,0.05); 
                color: #e6e1ea; 
                border-radius: 8px;
                padding: 10px;
            }
            button:hover { background-color: rgba(255,143,189,0.2); }
            #save-button { 
                background-color: #ff8fbd; 
                color: #1e2023; 
                font-weight: bold; 
            }
            #save-button:hover { background-color: #ffb3d1; }
            label { font-family: "JetBrainsMono Nerd Font"; margin-bottom: 2px; }
        """
        css_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

if __name__ == "__main__":
    AikoUserCardEditor()
    Gtk.main()
