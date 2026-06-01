import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import os
import sys
import datetime

class AikoClock(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Clock")
        self.set_name("aiko-clock-window")
        self.set_role("aiko-clock")
        self.set_wmclass("aiko-clock", "aiko-clock")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(200, 120)

        # Load CSS
        self.load_css()

        # Main Box (Transparent)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Padding container
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        content_vbox.set_margin_top(20)
        content_vbox.set_margin_bottom(20)
        content_vbox.set_margin_start(20)
        content_vbox.set_margin_end(20)
        self.styled_container.pack_start(content_vbox, True, True, 0)

        # Time Label
        self.time_label = Gtk.Label()
        self.time_label.set_name("clock-time")
        content_vbox.pack_start(self.time_label, True, True, 0)

        # Date Label
        self.date_label = Gtk.Label()
        self.date_label.set_name("clock-date")
        content_vbox.pack_start(self.date_label, True, True, 0)

        # Initial Update
        self.update_clock()
        
        # Refresh every second
        GLib.timeout_add_seconds(1, self.update_clock)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def update_clock(self):
        now = datetime.datetime.now()
        self.time_label.set_text(now.strftime("%H:%M"))
        self.date_label.set_text(now.strftime("%B %d, %Y"))
        return True

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    try:
        AikoClock()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoClock: {e}")
        sys.exit(1)
