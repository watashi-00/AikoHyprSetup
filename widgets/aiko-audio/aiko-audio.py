import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib

# Force dark theme variant
settings = Gtk.Settings.get_default()
if settings:
    settings.set_property("gtk-application-prefer-dark-theme", True)

import os
import sys
import subprocess
import re

class AikoAudio(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Audio Manager")
        
        # Identity for Hyprland rules
        self.set_name("aiko-audio-window")
        self.set_role("aiko-audio")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(360, 420)
        self.set_keep_above(False)  # Ensure focus transitions work cleanly
        self.set_position(Gtk.WindowPosition.CENTER)

        # Load CSS
        self.load_css()

        # Main Container
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
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

        title_label = Gtk.Label(label="Audio & Headphone Settings")
        title_label.set_name("header-title")
        header_hbox.pack_start(title_label, False, False, 0)

        # Section 1: Channel Balance
        balance_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        balance_frame.set_name("settings-section")
        balance_frame.set_margin_start(10)
        balance_frame.set_margin_end(10)
        self.styled_container.pack_start(balance_frame, False, False, 0)

        balance_title = Gtk.Label(label="Channel Volume & Balance")
        balance_title.set_name("section-title")
        balance_title.set_xalign(0.0)
        balance_title.set_yalign(0.5)
        balance_frame.pack_start(balance_title, False, False, 0)

        # Left channel slider
        left_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        left_label = Gtk.Label(label="Left")
        left_label.set_name("channel-label")
        left_hbox.pack_start(left_label, False, False, 0)

        self.left_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.left_scale.set_name("volume-scale")
        self.left_scale.set_value_pos(Gtk.PositionType.RIGHT)
        self.left_scale.set_hexpand(True)
        self.left_scale_handler = self.left_scale.connect("value-changed", self.on_left_changed)
        left_hbox.pack_start(self.left_scale, True, True, 0)
        balance_frame.pack_start(left_hbox, False, False, 0)

        # Right channel slider
        right_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        right_label = Gtk.Label(label="Right")
        right_label.set_name("channel-label")
        right_hbox.pack_start(right_label, False, False, 0)

        self.right_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.right_scale.set_name("volume-scale")
        self.right_scale.set_value_pos(Gtk.PositionType.RIGHT)
        self.right_scale.set_hexpand(True)
        self.right_scale_handler = self.right_scale.connect("value-changed", self.on_right_changed)
        right_hbox.pack_start(self.right_scale, True, True, 0)
        balance_frame.pack_start(right_hbox, False, False, 0)

        # Lock Channels checkbox
        self.lock_checkbox = Gtk.CheckButton(label="Lock Channels Together")
        self.lock_checkbox.set_name("lock-checkbox")
        self.lock_checkbox.set_active(True)
        balance_frame.pack_start(self.lock_checkbox, False, False, 0)

        # Reset Balance button
        self.reset_btn = Gtk.Button(label="Reset Balance (Keep Volume Level)")
        self.reset_btn.set_name("action-button")
        self.reset_btn.connect("clicked", self.on_reset_clicked)
        balance_frame.pack_start(self.reset_btn, False, False, 0)

        # Section 2: Headphone Fix/Driver
        driver_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        driver_frame.set_name("settings-section")
        driver_frame.set_margin_start(10)
        driver_frame.set_margin_end(10)
        self.styled_container.pack_start(driver_frame, False, False, 0)

        driver_title = Gtk.Label(label="Headphone Compatibility Fix")
        driver_title.set_name("section-title")
        driver_title.set_xalign(0.0)
        driver_title.set_yalign(0.5)
        driver_frame.pack_start(driver_title, False, False, 0)

        driver_desc = Gtk.Label(label="If your headphones only play on one side, have static, or are not detected by the jack, click below to install compatibility drivers & configuration fixes.")
        driver_desc.set_line_wrap(True)
        driver_desc.set_name("section-desc")
        driver_desc.set_xalign(0.0)
        driver_desc.set_yalign(0.5)
        driver_frame.pack_start(driver_desc, False, False, 0)

        self.install_btn = Gtk.Button(label="Install Headphone Driver & Fixes")
        self.install_btn.set_name("install-button")
        self.install_btn.connect("clicked", self.on_install_clicked)
        driver_frame.pack_start(self.install_btn, False, False, 0)

        # Bottom Close button
        close_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        close_hbox.set_margin_start(10)
        close_hbox.set_margin_end(10)
        close_hbox.set_margin_bottom(5)
        self.styled_container.pack_end(close_hbox, False, False, 0)

        close_btn = Gtk.Button(label="Close")
        close_btn.set_name("close-button")
        close_btn.set_hexpand(True)
        close_btn.connect("clicked", lambda w: self.destroy())
        close_hbox.pack_start(close_btn, True, True, 0)

        # Load current volume
        self.updating_volume = False
        self.update_volumes()

        # Connect events
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def update_volumes(self):
        self.updating_volume = True
        left, right = self.get_pactl_volumes()
        self.left_scale.set_value(left)
        self.right_scale.set_value(right)
        
        # If volumes are different, unlock checkbox automatically
        if left != right:
            self.lock_checkbox.set_active(False)
            
        self.updating_volume = False

    def get_pactl_volumes(self):
        try:
            res = subprocess.run(["pactl", "get-sink-volume", "@DEFAULT_SINK@"], capture_output=True, text=True, check=True)
            percentages = re.findall(r'(\d+)%', res.stdout)
            if len(percentages) >= 2:
                return int(percentages[0]), int(percentages[1])
            elif len(percentages) == 1:
                return int(percentages[0]), int(percentages[0])
        except Exception as e:
            print(f"Error: {e}")
        return 50, 50

    def on_left_changed(self, scale):
        if self.updating_volume:
            return
        val = int(scale.get_value())
        if self.lock_checkbox.get_active():
            self.updating_volume = True
            self.right_scale.set_value(val)
            self.updating_volume = False
            self.apply_volumes(val, val)
        else:
            right_val = int(self.right_scale.get_value())
            self.apply_volumes(val, right_val)

    def on_right_changed(self, scale):
        if self.updating_volume:
            return
        val = int(scale.get_value())
        if self.lock_checkbox.get_active():
            self.updating_volume = True
            self.left_scale.set_value(val)
            self.updating_volume = False
            self.apply_volumes(val, val)
        else:
            left_val = int(self.left_scale.get_value())
            self.apply_volumes(left_val, val)

    def apply_volumes(self, left, right):
        try:
            subprocess.run(["pactl", f"set-sink-volume", "@DEFAULT_SINK@", f"{left}%", f"{right}%"], check=True)
        except Exception as e:
            print(f"Error setting volumes: {e}")

    def on_reset_clicked(self, btn):
        # Reset balance to match the higher of the two levels, or average
        left, right = self.get_pactl_volumes()
        max_vol = max(left, right)
        if max_vol == 0:
            max_vol = 50
        
        self.updating_volume = True
        self.left_scale.set_value(max_vol)
        self.right_scale.set_value(max_vol)
        self.lock_checkbox.set_active(True)
        self.updating_volume = False
        self.apply_volumes(max_vol, max_vol)

    def on_install_clicked(self, btn):
        # 1. Ask for password via Zenity GUI popup
        try:
            res = subprocess.run([
                "zenity", "--password", 
                "--title=Authentication Required", 
                "--text=Aiko Audio Manager needs administrative privileges to install drivers. Please enter your password:"
            ], capture_output=True, text=True)
            
            if res.returncode != 0:
                # User cancelled or closed the dialog
                return
                
            password = res.stdout.strip()
            if not password:
                return
        except Exception as e:
            self.show_message_dialog(
                Gtk.MessageType.ERROR,
                "Authentication Error",
                f"Failed to open authentication dialog: {e}"
            )
            return

        # Disable button during install
        self.install_btn.set_sensitive(False)
        self.install_btn.set_label("Installing...")
        
        script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "install_drivers.sh")
        
        import threading
        def run_install():
            try:
                # Run script with sudo -S to pipe password
                proc = subprocess.Popen(
                    ["sudo", "-S", "bash", script_path], 
                    stdin=subprocess.PIPE, 
                    stdout=subprocess.PIPE, 
                    stderr=subprocess.PIPE, 
                    text=True
                )
                
                # Pass password to stdin
                stdout, stderr = proc.communicate(input=f"{password}\n")
                
                def on_done():
                    if proc.returncode == 0:
                        self.show_message_dialog(
                            Gtk.MessageType.INFO, 
                            "Installation Success", 
                            "Drivers and compatibility configuration successfully installed!\n\nPlease restart your computer to apply the changes."
                        )
                    else:
                        # Check if it was incorrect password
                        err_msg = stderr.strip() if stderr else "Installation failed."
                        if "incorrect password" in err_msg.lower() or "sorry, try again" in err_msg.lower():
                            err_msg = "Incorrect password. Please try again."
                        self.show_message_dialog(
                            Gtk.MessageType.ERROR, 
                            "Installation Failed", 
                            err_msg
                        )
                    self.install_btn.set_sensitive(True)
                    self.install_btn.set_label("Install Headphone Driver & Fixes")
                
                GLib.idle_add(on_done)
            except Exception as e:
                def on_err():
                    self.show_message_dialog(
                        Gtk.MessageType.ERROR, 
                        "Execution Error", 
                        f"Failed to start installer:\n{e}"
                    )
                    self.install_btn.set_sensitive(True)
                    self.install_btn.set_label("Install Headphone Driver & Fixes")
                GLib.idle_add(on_err)
                
        threading.Thread(target=run_install, daemon=True).start()

    def show_message_dialog(self, type_msg, title, text):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=type_msg,
            buttons=Gtk.ButtonsType.OK,
            text=title
        )
        dialog.format_secondary_text(text)
        dialog.run()
        dialog.destroy()

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
    win = AikoAudio()
    Gtk.main()
