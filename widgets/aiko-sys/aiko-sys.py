import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib

# Force dark theme variant
settings = Gtk.Settings.get_default()
if settings:
    settings.set_property("gtk-application-prefer-dark-theme", True)

import os
import sys
import psutil

class AikoSys(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko System")
        
        # Identity for Hyprland rules
        self.set_role("aiko-sys")
        # wmclass is deprecated, use set_name for CSS and role/class for Hyprland
        # self.set_wmclass("aiko-sys", "aiko-sys")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(360, 400)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_name("aiko-sys-window")

        # CSS setup
        self.load_css()

        # Main Container
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Style context for the main container (where the border/bg lives)
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        self.stats_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        self.stats_box.set_margin_top(25)
        self.stats_box.set_margin_bottom(25)
        self.stats_box.set_margin_start(25)
        self.stats_box.set_margin_end(25)
        self.styled_container.pack_start(self.stats_box, True, True, 0)

        # Initialize progress bars and labels
        self.resources = {}
        
        self.create_resource_row("CPU", "󰍛")
        self.create_resource_row("RAM", "󰘚")
        self.create_resource_row("Swap", "󰓡")
        
        # Disk resources will be dynamic
        self.disk_rows = {}
        self.update_disks()

        # Update loop
        GLib.timeout_add_seconds(2, self.update_stats)
        self.update_stats()

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def create_resource_row(self, name, icon):
        row_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        row_vbox.set_name(f"resource-row-{name.lower()}")

        header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        
        icon_label = Gtk.Label(label=icon)
        icon_label.set_name("resource-icon")
        header_hbox.pack_start(icon_label, False, False, 0)

        name_label = Gtk.Label(label=name)
        name_label.set_name("resource-name")
        header_hbox.pack_start(name_label, False, False, 0)

        value_label = Gtk.Label(label="0%")
        value_label.set_name("resource-value")
        header_hbox.pack_end(value_label, False, False, 0)

        row_vbox.pack_start(header_hbox, False, False, 0)

        progress = Gtk.ProgressBar()
        progress.set_name("resource-progress")
        row_vbox.pack_start(progress, False, False, 0)

        self.stats_box.pack_start(row_vbox, False, False, 0)
        self.resources[name] = {"progress": progress, "value": value_label}

    def update_disks(self):
        # Clear existing disk rows if any
        for name, widgets in self.disk_rows.items():
            self.stats_box.remove(widgets["row"])
        self.disk_rows = {}

        # Detect disks (all physical partitions)
        partitions = psutil.disk_partitions(all=False)
        seen_mounts = set()
        
        for part in partitions:
            if not part.device.startswith('/dev/'): continue
            if part.mountpoint in seen_mounts: continue
            if part.mountpoint == '/boot' or part.mountpoint.startswith('/boot/'): continue

            try:
                usage = psutil.disk_usage(part.mountpoint)
                if usage.total < 1024**3: continue

                name = f"Disk ({part.mountpoint})"
                
                row_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
                header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                
                icon_label = Gtk.Label(label="󰋊")
                icon_label.set_name("resource-icon")
                header_hbox.pack_start(icon_label, False, False, 0)

                name_label = Gtk.Label(label=name)
                name_label.set_name("resource-name")
                header_hbox.pack_start(name_label, False, False, 0)

                value_label = Gtk.Label(label="0/0 GiB")
                value_label.set_name("resource-value")
                header_hbox.pack_end(value_label, False, False, 0)

                row_vbox.pack_start(header_hbox, False, False, 0)

                progress = Gtk.ProgressBar()
                progress.set_name("resource-progress")
                row_vbox.pack_start(progress, False, False, 0)

                self.stats_box.pack_start(row_vbox, False, False, 0)
                self.disk_rows[part.mountpoint] = {
                    "progress": progress, 
                    "value": value_label, 
                    "row": row_vbox
                }
                seen_mounts.add(part.mountpoint)
            except:
                continue

    def update_stats(self):
        # CPU
        cpu_percent = psutil.cpu_percent()
        self.resources["CPU"]["progress"].set_fraction(cpu_percent / 100.0)
        self.resources["CPU"]["value"].set_text(f"{cpu_percent}%")

        # RAM
        ram = psutil.virtual_memory()
        self.resources["RAM"]["progress"].set_fraction(ram.percent / 100.0)
        self.resources["RAM"]["value"].set_text(f"{self.to_gb(ram.used)} / {self.to_gb(ram.total)} GiB")

        # Swap
        swap = psutil.swap_memory()
        self.resources["Swap"]["progress"].set_fraction(swap.percent / 100.0)
        self.resources["Swap"]["value"].set_text(f"{self.to_gb(swap.used)} / {self.to_gb(swap.total)} GiB")

        # Disks
        for mountpoint, widgets in self.disk_rows.items():
            try:
                usage = psutil.disk_usage(mountpoint)
                widgets["progress"].set_fraction(usage.percent / 100.0)
                widgets["value"].set_text(f"{self.to_gb(usage.used)} / {self.to_gb(usage.total)} GiB")
            except:
                continue

        return True

    def to_gb(self, bytes):
        return f"{bytes / (1024**3):.2f}"

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

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        if (event.state & Gdk.ModifierType.CONTROL_MASK):
            if event.keyval == Gdk.KEY_q or event.keyval == Gdk.KEY_w:
                self.destroy()

if __name__ == "__main__":
    AikoSys()
    Gtk.main()
