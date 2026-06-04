import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os
import sys
import json
import subprocess
import re

class AikoMonitors(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Monitors")
        
        self.set_name("aiko-monitors-window")
        self.set_role("aiko-monitors")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(400, 500)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load CSS
        self.load_css()

        # Main Container
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        self.styled_container.set_name("main-container")
        self.styled_container.set_margin_top(10)
        self.styled_container.set_margin_bottom(10)
        self.styled_container.set_margin_start(10)
        self.styled_container.set_margin_end(10)
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Header
        header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header_hbox.set_margin_top(15)
        header_hbox.set_margin_start(20)
        header_hbox.set_margin_end(20)
        self.styled_container.pack_start(header_hbox, False, False, 0)

        title_label = Gtk.Label(label="Monitor Configuration")
        title_label.set_name("header-title")
        header_hbox.pack_start(title_label, False, False, 0)

        # Monitor List
        self.list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.list_box.set_margin_start(20)
        self.list_box.set_margin_end(20)
        
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(self.list_box)
        self.styled_container.pack_start(scroll, True, True, 0)

        # Bottom Buttons
        btn_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        btn_hbox.set_margin_bottom(20)
        btn_hbox.set_margin_start(20)
        btn_hbox.set_margin_end(20)
        self.styled_container.pack_end(btn_hbox, False, False, 0)

        apply_btn = Gtk.Button(label="Save & Apply Settings")
        apply_btn.set_name("apply-button")
        apply_btn.set_hexpand(True)
        apply_btn.connect("clicked", self.on_apply_clicked)
        btn_hbox.pack_start(apply_btn, True, True, 0)

        # Data
        self.monitors_data = []
        self.rows = []
        self.refresh_monitors()

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def refresh_monitors(self):
        # Clear existing rows
        for row in self.rows:
            self.list_box.remove(row)
        self.rows = []

        try:
            output = subprocess.check_output(["hyprctl", "monitors", "-j"]).decode("utf-8")
            self.monitors_data = json.loads(output)
        except Exception as e:
            print(f"Error fetching monitors: {e}")
            return

        for mon in self.monitors_data:
            self.create_monitor_row(mon)

    def create_monitor_row(self, mon):
        row_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        row_vbox.set_name("monitor-row")
        row_vbox.set_margin_top(10)
        row_vbox.set_margin_bottom(10)
        row_vbox.set_margin_start(10)
        row_vbox.set_margin_end(10)
        
        # Monitor Info
        name_label = Gtk.Label()
        name_label.set_markup(f"<span font_weight='800'>{mon['name']}</span>")
        name_label.set_name("monitor-name")
        name_label.set_halign(Gtk.Align.START)
        row_vbox.pack_start(name_label, False, False, 0)

        details_label = Gtk.Label(label=f"{mon['width']}x{mon['height']} @ {mon['refreshRate']:.0f}Hz")
        details_label.set_name("monitor-details")
        details_label.set_halign(Gtk.Align.START)
        row_vbox.pack_start(details_label, False, False, 0)

        # Rotation Selector
        rot_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        rot_hbox.set_margin_top(5)
        row_vbox.pack_start(rot_hbox, False, False, 0)

        rot_label = Gtk.Label(label="Rotation:")
        rot_label.set_name("rotation-label")
        rot_hbox.pack_start(rot_label, False, False, 0)

        rot_combo = Gtk.ComboBoxText()
        rot_combo.append("0", "Normal (0°)")
        rot_combo.append("1", "Portrait (90°)")
        rot_combo.append("2", "Inverted (180°)")
        rot_combo.append("3", "Portrait Inverted (270°)")
        
        # Set current transform
        current_transform = mon.get("transform", 0)
        rot_combo.set_active(current_transform)
        rot_hbox.pack_start(rot_combo, True, True, 0)

        self.list_box.pack_start(row_vbox, False, False, 0)
        self.rows.append(row_vbox)
        
        # Store widgets for later
        mon["rot_combo"] = rot_combo

    def on_apply_clicked(self, widget):
        hypr_conf_path = os.path.expanduser("~/.config/hypr/hyprland.conf")
        if not os.path.exists(hypr_conf_path):
            print("hyprland.conf not found")
            return

        with open(hypr_conf_path, "r") as f:
            lines = f.readlines()

        changes_made = False
        for mon in self.monitors_data:
            new_rot = int(mon["rot_combo"].get_active_id())
            if new_rot != mon.get("transform", 0):
                # Apply live
                cmd = f"monitor {mon['name']},{mon['width']}x{mon['height']}@{mon['refreshRate']:.0f},{mon['x']}x{mon['y']},{mon['scale']:.1f},transform,{new_rot}"
                subprocess.run(["hyprctl", "keyword"] + cmd.split())
                
                # Update file lines
                # Format: monitor = name, res, offset, scale, transform, ...
                pattern = re.compile(rf'^\s*monitor\s*=\s*{re.escape(mon["name"])}', re.IGNORECASE)
                new_line = f"monitor = {mon['name']}, {mon['width']}x{mon['height']}@{mon['refreshRate']:.0f}, {mon['x']}x{mon['y']}, {mon['scale']:.1f}, transform, {new_rot}\n"
                
                found = False
                for i, line in enumerate(lines):
                    if pattern.match(line):
                        lines[i] = new_line
                        found = True
                        changes_made = True
                        break
                
                if not found:
                    # Insert before #autostart or just at the end
                    inserted = False
                    for i, line in enumerate(lines):
                        if "#autostart" in line.lower() or "# autostart" in line.lower():
                            lines.insert(i, new_line + "\n")
                            inserted = True
                            changes_made = True
                            break
                    if not inserted:
                        lines.append("\n" + new_line)
                        changes_made = True

        if changes_made:
            with open(hypr_conf_path, "w") as f:
                f.writelines(lines)
            
            # Notify
            subprocess.run(["notify-send", "Monitor Config", "Settings applied and saved to hyprland.conf", "-i", "display"])
            self.destroy()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        
        # Try to find current theme from global style.css if possible, otherwise pink
        theme_name = "pink-anime"
        waybar_style = os.path.expanduser("~/.config/waybar/style.css")
        if os.path.islink(waybar_style):
            target = os.readlink(waybar_style)
            if "black-white" in target: theme_name = "black-white"
            elif "cyber-blue" in target: theme_name = "cyber-blue"

        theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes", f"{theme_name}.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    try:
        AikoMonitors()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoMonitors: {e}")
        sys.exit(1)
