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
        self.set_default_size(450, 600)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load CSS
        self.load_css()

        # Main Container (Transparent wrapper)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
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

        # Monitor List scrollable area
        self.list_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.list_box.set_margin_start(15)
        self.list_box.set_margin_end(15)
        
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

        # Data initialization
        self.monitors_data = []
        self.rows = []
        self.primary_selected_name = None
        self.primary_radio_group = None
        
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
        self.update_position_sensitivities()

    def parse_hypr_config_for_monitor(self, monitor_name):
        hypr_conf_path = os.path.expanduser("~/.config/hypr/hyprland.conf")
        if not os.path.exists(hypr_conf_path):
            return {}
        
        # Matches monitor = name, res, position, scale, extra_options
        pattern = re.compile(rf'^\s*monitor\s*=\s*{re.escape(monitor_name)}\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)(.*)', re.IGNORECASE)
        with open(hypr_conf_path, "r") as f:
            for line in f:
                m = pattern.match(line)
                if m:
                    res = m.group(1).strip()
                    pos = m.group(2).strip()
                    scale = m.group(3).strip()
                    extra = m.group(4).strip()
                    
                    transform = 0
                    if "transform" in extra:
                        t_match = re.search(r'transform\s*,\s*(\d+)', extra)
                        if t_match:
                            transform = int(t_match.group(1))
                            
                    return {
                        "res": res,
                        "pos": pos,
                        "scale": scale,
                        "transform": transform
                    }
        return {}

    def refresh_monitors(self):
        for row in self.rows:
            self.list_box.remove(row)
        self.rows = []

        try:
            output = subprocess.check_output(["hyprctl", "monitors", "-j"]).decode("utf-8")
            self.monitors_data = json.loads(output)
        except Exception as e:
            print(f"Error fetching monitors: {e}")
            return

        # Determine primary screen name based on active offset (0, 0)
        # Fallback to first monitor if none have 0x0
        self.primary_selected_name = None
        for mon in self.monitors_data:
            if mon.get('x', 0) == 0 and mon.get('y', 0) == 0:
                self.primary_selected_name = mon['name']
                break
        if not self.primary_selected_name and self.monitors_data:
            self.primary_selected_name = self.monitors_data[0]['name']

        # Reset radio group
        self.primary_radio_group = None

        for mon in self.monitors_data:
            self.create_monitor_row(mon)

    def create_monitor_row(self, mon):
        row_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        row_vbox.set_name("monitor-row")
        row_vbox.set_margin_top(8)
        row_vbox.set_margin_bottom(8)
        row_vbox.set_margin_start(10)
        row_vbox.set_margin_end(10)
        
        # Header Row (Monitor Name & Primary Radio Button)
        header_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row_vbox.pack_start(header_row, False, False, 0)

        name_label = Gtk.Label()
        name_label.set_markup(f"<span font_weight='800'>{mon['name']}</span> <span font_size='small'>({mon['model']})</span>")
        name_label.set_name("monitor-name")
        name_label.set_halign(Gtk.Align.START)
        header_row.pack_start(name_label, False, False, 0)

        # Radio Button for Primary Designation
        if not self.primary_radio_group:
            self.primary_radio_group = Gtk.RadioButton.new_with_label(None, "Primary")
            primary_radio = self.primary_radio_group
        else:
            primary_radio = Gtk.RadioButton.new_with_label_from_widget(self.primary_radio_group, "Primary")
            
        primary_radio.set_name("primary-radio")
        is_primary = (mon['name'] == self.primary_selected_name)
        primary_radio.set_active(is_primary)
        primary_radio.connect("toggled", self.on_primary_toggled, mon['name'])
        header_row.pack_end(primary_radio, False, False, 0)

        # Details Label
        details_label = Gtk.Label(label=f"Native: {mon['width']}x{mon['height']}")
        details_label.set_name("monitor-details")
        details_label.set_halign(Gtk.Align.START)
        row_vbox.pack_start(details_label, False, False, 0)

        # Read config override settings
        config_settings = self.parse_hypr_config_for_monitor(mon['name'])

        # Hz Selector
        hz_combo = Gtk.ComboBoxText()
        current_res = f"{mon['width']}x{mon['height']}"
        rates = []
        for mode in mon.get("availableModes", []):
            if mode.startswith(current_res):
                match = re.search(r'@([\d.]+)(?:Hz)?', mode)
                if match:
                    hz = float(match.group(1))
                    hz_str = f"{hz:.0f}" if hz.is_integer() else f"{hz:.2f}"
                    rates.append(hz_str)
        
        rates = sorted(list(set(rates)), key=float, reverse=True)
        current_hz = f"{mon['refreshRate']:.0f}" if mon['refreshRate'].is_integer() else f"{mon['refreshRate']:.2f}"
        
        # If config has a configured refresh rate, use it
        config_res_rate = config_settings.get("res", "")
        if "@" in config_res_rate:
            config_hz = config_res_rate.split("@")[1]
            try:
                float(config_hz)
                current_hz = config_hz
            except ValueError:
                pass

        if current_hz not in rates:
            rates.append(current_hz)
            rates = sorted(rates, key=float, reverse=True)

        for rate in rates:
            hz_combo.append(rate, f"{rate} Hz")
        hz_combo.set_active_id(current_hz)

        # Rotation Selector
        rot_combo = Gtk.ComboBoxText()
        rot_combo.append("0", "Normal (0°)")
        rot_combo.append("1", "Portrait (90°)")
        rot_combo.append("2", "Inverted (180°)")
        rot_combo.append("3", "Portrait Inverted (270°)")
        current_transform = config_settings.get("transform", mon.get("transform", 0))
        rot_combo.set_active(current_transform)

        # Position Selector
        pos_combo = Gtk.ComboBoxText()
        pos_combo.append("auto", "Auto Placement")
        pos_combo.append("auto-left", "Left of Main")
        pos_combo.append("auto-right", "Right of Main")
        pos_combo.append("auto-up", "Above Main")
        pos_combo.append("auto-down", "Below Main")

        current_pos = config_settings.get("pos", "auto")
        # Ensure non-primary screens don't get 0x0 default if they were offset before
        if current_pos == "0x0" and not is_primary:
            current_pos = "auto-right"

        if current_pos not in ["auto", "auto-left", "auto-right", "auto-up", "auto-down", "0x0"]:
            pos_combo.append(current_pos, f"Custom ({current_pos})")

        if is_primary:
            pos_combo.append("0x0", "Main Origin (0x0)")
            pos_combo.set_active_id("0x0")
        else:
            pos_combo.set_active_id(current_pos)

        # Controls Grid
        grid = Gtk.Grid()
        grid.set_column_spacing(12)
        grid.set_row_spacing(8)
        grid.set_margin_top(5)
        row_vbox.pack_start(grid, False, False, 0)

        hz_lbl = Gtk.Label(label="Refresh Rate:")
        hz_lbl.set_halign(Gtk.Align.START)
        grid.attach(hz_lbl, 0, 0, 1, 1)
        grid.attach(hz_combo, 1, 0, 1, 1)

        rot_lbl = Gtk.Label(label="Rotation:")
        rot_lbl.set_halign(Gtk.Align.START)
        grid.attach(rot_lbl, 0, 1, 1, 1)
        grid.attach(rot_combo, 1, 1, 1, 1)

        pos_lbl = Gtk.Label(label="Position:")
        pos_lbl.set_halign(Gtk.Align.START)
        grid.attach(pos_lbl, 0, 2, 1, 1)
        grid.attach(pos_combo, 1, 2, 1, 1)

        self.list_box.pack_start(row_vbox, False, False, 0)
        self.rows.append(row_vbox)
        
        # Store refs
        mon["primary_radio"] = primary_radio
        mon["hz_combo"] = hz_combo
        mon["rot_combo"] = rot_combo
        mon["pos_combo"] = pos_combo

    def on_primary_toggled(self, button, name):
        if button.get_active():
            self.primary_selected_name = name
            self.update_position_sensitivities()

    def update_position_sensitivities(self):
        for mon in self.monitors_data:
            is_primary = (mon['name'] == self.primary_selected_name)
            if is_primary:
                # Add 0x0 mapping if missing
                if "0x0" not in [x[0] for x in mon["pos_combo"].get_model()]:
                    mon["pos_combo"].append("0x0", "Main Origin (0x0)")
                mon["pos_combo"].set_active_id("0x0")
                mon["pos_combo"].set_sensitive(False)
            else:
                mon["pos_combo"].set_sensitive(True)
                if mon["pos_combo"].get_active_id() == "0x0":
                    mon["pos_combo"].set_active_id("auto-right")

    def on_apply_clicked(self, widget):
        hypr_conf_path = os.path.expanduser("~/.config/hypr/hyprland.conf")
        if not os.path.exists(hypr_conf_path):
            print("hyprland.conf not found")
            return

        with open(hypr_conf_path, "r") as f:
            lines = f.readlines()

        # Build monitor configuration lines, primary first
        prim_mon = None
        other_mons = []
        for mon in self.monitors_data:
            if mon['name'] == self.primary_selected_name:
                prim_mon = mon
            else:
                other_mons.append(mon)

        new_monitor_lines = []
        
        # 1. Generate primary monitor line
        if prim_mon:
            hz = prim_mon["hz_combo"].get_active_id()
            rot = prim_mon["rot_combo"].get_active_id()
            scale = f"{prim_mon.get('scale', 1.0):.1f}"
            new_monitor_lines.append(f"monitor = {prim_mon['name']}, {prim_mon['width']}x{prim_mon['height']}@{hz}, 0x0, {scale}, transform, {rot}\n")
            
        # 2. Generate other monitors lines
        for mon in other_mons:
            hz = mon["hz_combo"].get_active_id()
            rot = mon["rot_combo"].get_active_id()
            pos = mon["pos_combo"].get_active_id()
            scale = f"{mon.get('scale', 1.0):.1f}"
            new_monitor_lines.append(f"monitor = {mon['name']}, {mon['width']}x{mon['height']}@{hz}, {pos}, {scale}, transform, {rot}\n")

        # 3. Apply live setting updates dynamically to Hyprland
        for line in new_monitor_lines:
            # Strip "monitor = " prefix and trailing newline for hyprctl command
            hypr_cmd = line.strip().replace("monitor = ", "monitor ")
            subprocess.run(["hyprctl", "keyword"] + hypr_cmd.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # 4. Patch hyprland.conf file
        # Identify indices of all existing monitor lines
        monitor_indices = []
        for idx, line in enumerate(lines):
            # Matches "monitor = " or generic "monitor="
            if line.strip().startswith("monitor"):
                monitor_indices.append(idx)

        if monitor_indices:
            insert_idx = monitor_indices[0]
            # Strip old lines
            lines = [line for idx, line in enumerate(lines) if idx not in monitor_indices]
        else:
            # Fallback to insert after `#monitors` section, or at the end
            insert_idx = len(lines)
            for idx, line in enumerate(lines):
                if "#monitors" in line.lower() or "# monitors" in line.lower():
                    insert_idx = idx + 1
                    break

        # Insert new configuration lines
        for offset, newline in enumerate(new_monitor_lines):
            lines.insert(insert_idx + offset, newline)

        # Save to file
        with open(hypr_conf_path, "w") as f:
            f.writelines(lines)

        # 5. Restart Waybar to reload layouts correctly
        restart_script = os.path.expanduser("~/.config/waybar/scripts/restart-waybar.sh")
        if os.path.exists(restart_script):
            subprocess.Popen(["bash", restart_script])
        else:
            subprocess.Popen(["aiko", "--restart"])

        # 6. Notify user
        subprocess.run(["notify-send", "Monitor Config", "Monitors layout updated. Waybar restarted.", "-i", "display"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.destroy()

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
        AikoMonitors()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoMonitors: {e}")
        sys.exit(1)
