import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os
import sys
import subprocess

class AikoTimer(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Timer")
        self.set_name("aiko-timer-window")
        self.set_role("aiko-timer")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(320, 260)

        # Timer state
        self.total_seconds = 1500  # 25 mins default
        self.seconds_left = 1500
        self.running = False
        self.timer_id = None

        # Load CSS
        self.load_css()

        # Main Box (Transparent wrapper)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Padding container
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        content_vbox.set_margin_top(15)
        content_vbox.set_margin_bottom(15)
        content_vbox.set_margin_start(15)
        content_vbox.set_margin_end(15)
        self.styled_container.pack_start(content_vbox, True, True, 0)

        # Timer Display Label
        self.display_label = Gtk.Label(label="25:00")
        self.display_label.set_name("timer-display")
        content_vbox.pack_start(self.display_label, False, False, 0)

        # Progress Bar
        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_name("timer-progress")
        self.progress_bar.set_fraction(1.0)
        content_vbox.pack_start(self.progress_bar, False, False, 0)

        # Preset buttons box
        self.presets_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.presets_box.set_homogeneous(True)
        content_vbox.pack_start(self.presets_box, False, False, 0)

        presets = [("5m", 300), ("25m", 1500), ("50m", 3000)]
        for label, seconds in presets:
            btn = Gtk.Button(label=label)
            btn.set_name("preset-btn")
            btn.connect("clicked", self.on_preset_clicked, seconds)
            self.presets_box.pack_start(btn, True, True, 0)

        # Custom entry / spinner box
        self.custom_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        content_vbox.pack_start(self.custom_box, False, False, 0)

        min_lbl = Gtk.Label(label="Min:")
        min_lbl.set_name("custom-label")
        self.custom_box.pack_start(min_lbl, False, False, 0)

        adj = Gtk.Adjustment(value=25, lower=1, upper=180, step_increment=1, page_increment=5, page_size=0)
        self.spin_btn = Gtk.SpinButton(adjustment=adj, climb_rate=1.0, digits=0)
        self.spin_btn.set_name("time-spinner")
        self.custom_box.pack_start(self.spin_btn, True, True, 0)

        set_btn = Gtk.Button(label="Set")
        set_btn.set_name("set-btn")
        set_btn.connect("clicked", self.on_set_custom_time)
        self.custom_box.pack_start(set_btn, False, False, 0)

        # Control Box (Start/Pause, Reset)
        control_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        control_box.set_homogeneous(True)
        content_vbox.pack_start(control_box, False, False, 0)

        self.start_btn = Gtk.Button(label="Start")
        self.start_btn.set_name("control-start-btn")
        self.start_btn.connect("clicked", self.on_start_pause_clicked)
        control_box.pack_start(self.start_btn, True, True, 0)

        self.reset_btn = Gtk.Button(label="Reset")
        self.reset_btn.set_name("control-reset-btn")
        self.reset_btn.connect("clicked", self.on_reset_clicked)
        control_box.pack_start(self.reset_btn, True, True, 0)

        # Initial view update
        self.update_display()

        # Key press & Destroy
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Transparency support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def update_display(self):
        mins = self.seconds_left // 60
        secs = self.seconds_left % 60
        self.display_label.set_text(f"{mins:02d}:{secs:02d}")
        
        if self.total_seconds > 0:
            fraction = self.seconds_left / self.total_seconds
        else:
            fraction = 0.0
        self.progress_bar.set_fraction(fraction)

    def on_tick(self):
        if not self.running:
            return False

        if self.seconds_left > 0:
            self.seconds_left -= 1
            self.update_display()
            return True
        else:
            self.running = False
            self.start_btn.set_label("Start")
            self.presets_box.set_sensitive(True)
            self.custom_box.set_sensitive(True)
            self.update_display()
            self.notify_timer_up()
            return False

    def notify_timer_up(self):
        try:
            subprocess.run(["notify-send", "Aiko Timer", "Time's up!", "-i", "alarm-symbolic"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"Failed to send notification: {e}")

    def on_start_pause_clicked(self, widget):
        if self.running:
            self.running = False
            self.start_btn.set_label("Start")
            self.presets_box.set_sensitive(True)
            self.custom_box.set_sensitive(True)
        else:
            if self.seconds_left > 0:
                self.running = True
                self.start_btn.set_label("Pause")
                self.presets_box.set_sensitive(False)
                self.custom_box.set_sensitive(False)
                GLib.timeout_add_seconds(1, self.on_tick)

    def on_reset_clicked(self, widget):
        self.running = False
        self.start_btn.set_label("Start")
        self.seconds_left = self.total_seconds
        self.presets_box.set_sensitive(True)
        self.custom_box.set_sensitive(True)
        self.update_display()

    def on_preset_clicked(self, widget, seconds):
        if not self.running:
            self.total_seconds = seconds
            self.seconds_left = seconds
            self.update_display()

    def on_set_custom_time(self, widget):
        if not self.running:
            mins = int(self.spin_btn.get_value())
            self.total_seconds = mins * 60
            self.seconds_left = self.total_seconds
            self.update_display()

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
        AikoTimer()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoTimer: {e}")
        sys.exit(1)
