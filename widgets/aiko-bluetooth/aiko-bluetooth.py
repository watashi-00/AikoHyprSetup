#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import os
import sys
import subprocess
import threading
import re

class AikoBluetooth(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Bluetooth Manager")
        
        # Identity for Hyprland rules
        self.set_name("aiko-bluetooth-window")
        self.set_role("aiko-bluetooth")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(360, 420)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        # UI States
        self.is_scanning = False
        self.paired_devices = []
        self.available_devices = []
        self.power_state = False

        # Load CSS
        self.load_css()

        # Main Box (Transparent)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.styled_container.set_name("main-container")
        self.styled_container.set_margin_top(15)
        self.styled_container.set_margin_bottom(15)
        self.styled_container.set_margin_start(15)
        self.styled_container.set_margin_end(15)
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Header
        header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header_hbox.set_margin_start(10)
        header_hbox.set_margin_end(10)
        self.styled_container.pack_start(header_hbox, False, False, 0)

        title_label = Gtk.Label(label="Bluetooth Manager")
        title_label.set_name("header-title")
        header_hbox.pack_start(title_label, False, False, 0)

        # Power switch box
        power_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        power_hbox.set_margin_start(10)
        power_hbox.set_margin_end(10)
        self.styled_container.pack_start(power_hbox, False, False, 0)

        power_label = Gtk.Label(label="Enable Bluetooth")
        power_label.set_name("section-title")
        power_label.set_xalign(0.0)
        power_hbox.pack_start(power_label, True, True, 0)

        self.power_switch = Gtk.Switch()
        self.power_switch_handler = self.power_switch.connect("state-set", self.on_power_toggled)
        power_hbox.pack_end(self.power_switch, False, False, 0)

        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        self.styled_container.pack_start(sep, False, False, 2)

        # Device List Section
        self.device_scroll = Gtk.ScrolledWindow()
        self.device_scroll.set_name("device-scroll")
        self.device_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.styled_container.pack_start(self.device_scroll, True, True, 0)

        self.device_list_box = Gtk.ListBox()
        self.device_list_box.set_name("device-list")
        self.device_list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        self.device_scroll.add(self.device_list_box)

        # Status & Scan Row
        bottom_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        bottom_hbox.set_margin_start(10)
        bottom_hbox.set_margin_end(10)
        self.styled_container.pack_end(bottom_hbox, False, False, 0)

        self.status_label = Gtk.Label(label="Ready")
        self.status_label.set_name("section-desc")
        self.status_label.set_xalign(0.0)
        bottom_hbox.pack_start(self.status_label, True, True, 0)

        self.scan_btn = Gtk.Button(label="Scan")
        self.scan_btn.set_name("scan-button")
        self.scan_btn.connect("clicked", self.on_scan_clicked)
        bottom_hbox.pack_end(self.scan_btn, False, False, 0)

        self.close_btn = Gtk.Button(label="Close")
        self.close_btn.set_name("close-button")
        self.close_btn.connect("clicked", lambda w: self.destroy())
        bottom_hbox.pack_end(self.close_btn, False, False, 0)

        # Initial checks
        if not self.check_bluetoothctl():
            self.status_label.set_text("bluetoothctl missing!")
            self.power_switch.set_sensitive(False)
            self.scan_btn.set_sensitive(False)
        else:
            # Load initial states
            self.refresh_state()
            # Start timer loop to update state every 3 seconds
            GLib.timeout_add_seconds(3, self.periodic_update)

        # Key press and destroy
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.set_visual(visual)

        self.show_all()

    def check_bluetoothctl(self):
        try:
            subprocess.run(["which", "bluetoothctl"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            return True
        except:
            return False

    def periodic_update(self):
        if not self.is_scanning:
            threading.Thread(target=self.refresh_state_async).start()
        return True

    def refresh_state(self):
        threading.Thread(target=self.refresh_state_async).start()

    def refresh_state_async(self):
        # 1. Power State
        try:
            out = subprocess.check_output(["bluetoothctl", "show"], stderr=subprocess.DEVNULL).decode()
            pow_state = "Powered: yes" in out
        except:
            pow_state = False

        # 2. Devices
        paired = []
        if pow_state:
            try:
                raw_paired = subprocess.check_output(["bluetoothctl", "paired-devices"], stderr=subprocess.DEVNULL).decode()
                for line in raw_paired.strip().split("\n"):
                    if not line: continue
                    parts = line.split(" ", 2)
                    if len(parts) >= 3:
                        mac = parts[1]
                        name = parts[2]
                        
                        # Get connection details
                        info_out = subprocess.check_output(["bluetoothctl", "info", mac], stderr=subprocess.DEVNULL).decode()
                        connected = "Connected: yes" in info_out
                        icon = self.detect_icon_from_info(info_out)
                        
                        paired.append({
                            "mac": mac,
                            "name": name,
                            "connected": connected,
                            "paired": True,
                            "icon": icon
                        })
            except Exception as e:
                print(f"Error paired dev: {e}")

        GLib.idle_add(self.update_ui, pow_state, paired)

    def detect_icon_from_info(self, info_str):
        # Simple icon detection based on bluetoothctl info output
        info_lower = info_str.lower()
        if "icon: audio-card" in info_lower or "icon: audio-headset" in info_lower or "headset" in info_lower or "headphone" in info_lower:
            return "" # Headset
        elif "keyboard" in info_lower:
            return "" # Keyboard
        elif "mouse" in info_lower:
            return "" # Mouse/Pointer
        elif "gamepad" in info_lower or "joystick" in info_lower:
            return "" # Gamepad
        elif "phone" in info_lower:
            return "" # Mobile
        return "" # Generic bluetooth

    def update_ui(self, pow_state, paired_list):
        self.power_state = pow_state
        
        # Block handler to prevent loop when updating switch state
        self.power_switch.disconnect(self.power_switch_handler)
        self.power_switch.set_active(pow_state)
        self.power_switch_handler = self.power_switch.connect("state-set", self.on_power_toggled)

        self.scan_btn.set_sensitive(pow_state)

        # Clear old rows
        for child in self.device_list_box.get_children():
            self.device_list_box.remove(child)

        self.paired_devices = paired_list

        if not pow_state:
            row = Gtk.ListBoxRow()
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            box.set_margin_top(20)
            box.set_margin_bottom(20)
            lbl = Gtk.Label(label="Bluetooth is disabled.")
            lbl.set_name("section-desc")
            lbl.set_halign(Gtk.Align.CENTER)
            box.pack_start(lbl, True, True, 0)
            row.add(box)
            self.device_list_box.add(row)
        else:
            # Add Paired Devices
            if paired_list:
                lbl_row = Gtk.ListBoxRow()
                lbl_row.set_sensitive(False)
                lbl_box = Gtk.Box()
                lbl_box.set_margin_top(5)
                lbl_box.set_margin_bottom(5)
                lbl_box.set_margin_start(10)
                lbl = Gtk.Label(label="PAIRED DEVICES")
                lbl.set_name("section-title")
                lbl_box.pack_start(lbl, False, False, 0)
                lbl_row.add(lbl_box)
                self.device_list_box.add(lbl_row)

                for dev in paired_list:
                    row = self.create_device_row(dev)
                    self.device_list_box.add(row)

            # Add Scanned/Available Devices
            if self.available_devices:
                lbl_row = Gtk.ListBoxRow()
                lbl_row.set_sensitive(False)
                lbl_box = Gtk.Box()
                lbl_box.set_margin_top(15)
                lbl_box.set_margin_bottom(5)
                lbl_box.set_margin_start(10)
                lbl = Gtk.Label(label="AVAILABLE DEVICES")
                lbl.set_name("section-title")
                lbl_box.pack_start(lbl, False, False, 0)
                lbl_row.add(lbl_box)
                self.device_list_box.add(lbl_row)

                for dev in self.available_devices:
                    row = self.create_device_row(dev)
                    self.device_list_box.add(row)

            if not paired_list and not self.available_devices:
                row = Gtk.ListBoxRow()
                box = Gtk.Box()
                box.set_margin_top(20)
                box.set_margin_bottom(20)
                lbl = Gtk.Label(label="No devices found. Click scan.")
                lbl.set_name("section-desc")
                lbl.set_xalign(0.5)
                box.pack_start(lbl, True, True, 0)
                row.add(box)
                self.device_list_box.add(row)

        self.device_list_box.show_all()

    def create_device_row(self, dev):
        row = Gtk.ListBoxRow()
        row.set_name("device-row-wrapper")

        main_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        main_hbox.set_name("device-row")
        main_hbox.set_margin_top(6)
        main_hbox.set_margin_bottom(6)
        main_hbox.set_margin_start(8)
        main_hbox.set_margin_end(8)
        row.add(main_hbox)

        # Icon
        icon_lbl = Gtk.Label(label=dev.get("icon", ""))
        icon_lbl.set_name("device-icon")
        main_hbox.pack_start(icon_lbl, False, False, 0)

        # Name & Status
        info_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        main_hbox.pack_start(info_vbox, True, True, 0)

        name_lbl = Gtk.Label(label=dev["name"])
        name_lbl.set_name("device-name")
        name_lbl.set_xalign(0.0)
        name_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        name_lbl.set_max_width_chars(20)
        info_vbox.pack_start(name_lbl, False, False, 0)

        status_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        info_vbox.pack_start(status_hbox, False, False, 0)

        status_lbl = Gtk.Label(label="Paired" if dev["paired"] else "Available")
        status_lbl.set_name("device-status")
        status_lbl.set_xalign(0.0)
        status_hbox.pack_start(status_lbl, False, False, 0)

        if dev["paired"]:
            indicator = Gtk.Label()
            if dev["connected"]:
                indicator.set_text("● Connected")
                indicator.set_name("status-connected")
            else:
                indicator.set_text("● Disconnected")
                indicator.set_name("status-disconnected")
            indicator.get_style_context().add_class("status-indicator")
            status_hbox.pack_start(indicator, False, False, 0)

        # Actions
        actions_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        main_hbox.pack_end(actions_hbox, False, False, 0)

        if dev["paired"]:
            # Connect/Disconnect button
            conn_btn = Gtk.Button()
            conn_btn.set_name("action-btn")
            conn_btn.get_style_context().add_class("icon-button")
            if dev["connected"]:
                conn_btn.set_label("󰂱") # Disconnect icon
                conn_btn.connect("clicked", self.on_disconnect_clicked, dev)
            else:
                conn_btn.set_label("󰂰") # Connect icon
                conn_btn.connect("clicked", self.on_connect_clicked, dev)
            actions_hbox.pack_start(conn_btn, False, False, 0)

            # Unpair button
            unpair_btn = Gtk.Button(label="")
            unpair_btn.set_name("action-btn")
            unpair_btn.get_style_context().add_class("icon-button")
            unpair_btn.get_style_context().add_class("remove-btn")
            unpair_btn.connect("clicked", self.on_unpair_clicked, dev)
            actions_hbox.pack_start(unpair_btn, False, False, 0)
        else:
            # Pair & Connect button
            pair_btn = Gtk.Button(label="Pair")
            pair_btn.set_name("action-btn")
            pair_btn.connect("clicked", self.on_pair_clicked, dev)
            actions_hbox.pack_start(pair_btn, False, False, 0)

        return row

    def on_power_toggled(self, switch, state):
        self.status_label.set_text("Switching...")
        threading.Thread(target=self.set_power_async, args=(state,)).start()
        return True

    def set_power_async(self, state):
        cmd = "power on" if state else "power off"
        try:
            subprocess.run(["bluetoothctl", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            # wait a bit
            import time
            time.sleep(1)
        except:
            pass
        self.refresh_state_async()

    def on_scan_clicked(self, widget):
        if self.is_scanning: return
        self.is_scanning = True
        self.scan_btn.set_sensitive(False)
        self.status_label.set_text("Scanning devices...")
        threading.Thread(target=self.scan_async).start()

    def scan_async(self):
        try:
            # Scan asynchronously for 5 seconds
            subprocess.run(["bluetoothctl", "--timeout", "5", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            # Fetch discovered devices
            raw_devices = subprocess.check_output(["bluetoothctl", "devices"], stderr=subprocess.DEVNULL).decode()
            
            # Get list of paired MAC addresses to filter them out
            paired_macs = {dev["mac"] for dev in self.paired_devices}

            new_devices = []
            for line in raw_devices.strip().split("\n"):
                if not line: continue
                parts = line.split(" ", 2)
                if len(parts) >= 3:
                    mac = parts[1]
                    name = parts[2]
                    
                    if mac not in paired_macs:
                        new_devices.append({
                            "mac": mac,
                            "name": name,
                            "connected": False,
                            "paired": False,
                            "icon": "" # Generic scanned icon
                        })
            self.available_devices = new_devices
        except Exception as e:
            print(f"Scan error: {e}")

        GLib.idle_add(self.scan_finished)

    def scan_finished(self):
        self.is_scanning = False
        self.scan_btn.set_sensitive(True)
        self.status_label.set_text("Scan finished.")
        self.refresh_state()

    def on_connect_clicked(self, widget, dev):
        self.status_label.set_text(f"Connecting to {dev['name']}...")
        threading.Thread(target=self.connect_async, args=(dev,)).start()

    def connect_async(self, dev):
        try:
            subprocess.run(["bluetoothctl", "connect", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        self.refresh_state_async()

    def on_disconnect_clicked(self, widget, dev):
        self.status_label.set_text(f"Disconnecting from {dev['name']}...")
        threading.Thread(target=self.disconnect_async, args=(dev,)).start()

    def disconnect_async(self, dev):
        try:
            subprocess.run(["bluetoothctl", "disconnect", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        self.refresh_state_async()

    def on_unpair_clicked(self, widget, dev):
        self.status_label.set_text(f"Removing {dev['name']}...")
        threading.Thread(target=self.unpair_async, args=(dev,)).start()

    def unpair_async(self, dev):
        try:
            subprocess.run(["bluetoothctl", "remove", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        self.refresh_state_async()

    def on_pair_clicked(self, widget, dev):
        self.status_label.set_text(f"Pairing with {dev['name']}...")
        threading.Thread(target=self.pair_async, args=(dev,)).start()

    def pair_async(self, dev):
        try:
            # Pair
            subprocess.run(["bluetoothctl", "pair", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Trust
            subprocess.run(["bluetoothctl", "trust", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Connect
            subprocess.run(["bluetoothctl", "connect", dev["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        # Remove from scanned list
        self.available_devices = [d for d in self.available_devices if d["mac"] != dev["mac"]]
        self.refresh_state_async()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # 1. Try theme.css symlink first (unified mapping)
        theme_path = os.path.join(self.script_dir, "theme.css")
        if not os.path.exists(theme_path):
            # 2. Fallback to detecting style.css symlink target
            theme_name = "pink-anime"
            waybar_style = os.path.expanduser("~/.config/waybar/style.css")
            if os.path.islink(waybar_style):
                target = os.readlink(waybar_style)
                if "black-white" in target: theme_name = "black-white"
                elif "cyber-blue" in target: theme_name = "cyber-blue"
            theme_path = os.path.join(self.script_dir, "themes", f"{theme_name}.css")
            
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    try:
        AikoBluetooth()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoBluetooth: {e}")
        sys.exit(1)
