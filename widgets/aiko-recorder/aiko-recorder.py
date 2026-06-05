import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import os
import sys
import subprocess
import signal

class AikoRecorder(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Recorder")
        self.set_name("aiko-recorder-window")
        self.set_role("aiko-recorder")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(320, 240)

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
        content_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        content_vbox.set_margin_top(20)
        content_vbox.set_margin_bottom(20)
        content_vbox.set_margin_start(20)
        content_vbox.set_margin_end(20)
        self.styled_container.pack_start(content_vbox, True, True, 0)

        # Title/Status Label
        self.status_label = Gtk.Label(label="Ready to Record")
        self.status_label.set_name("recorder-status")
        content_vbox.pack_start(self.status_label, False, False, 0)

        # Options Box (Audio Toggle)
        options_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        content_vbox.pack_start(options_box, False, False, 0)

        self.audio_toggle = Gtk.CheckButton(label="Record Microphone Audio")
        self.audio_toggle.set_name("audio-toggle")
        self.audio_toggle.set_active(True)
        options_box.pack_start(self.audio_toggle, True, True, 0)

        # Record Buttons Box (Full / Area)
        self.buttons_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.buttons_box.set_homogeneous(True)
        content_vbox.pack_start(self.buttons_box, False, False, 0)

        self.full_btn = Gtk.Button(label="Fullscreen")
        self.full_btn.set_name("action-btn")
        self.full_btn.connect("clicked", self.on_start_recording, False)
        self.buttons_box.pack_start(self.full_btn, True, True, 0)

        self.area_btn = Gtk.Button(label="Select Area")
        self.area_btn.set_name("action-btn")
        self.area_btn.connect("clicked", self.on_start_recording, True)
        self.buttons_box.pack_start(self.area_btn, True, True, 0)

        # Stop Button
        self.stop_btn = Gtk.Button(label="Stop Recording")
        self.stop_btn.set_name("stop-btn")
        self.stop_btn.connect("clicked", self.on_stop_recording)
        self.stop_btn.set_visible(False)
        content_vbox.pack_start(self.stop_btn, False, False, 0)

        # Periodically check status
        GLib.timeout_add_seconds(1, self.check_recording_status)

        # Key press & Destroy
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Transparency support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def is_wf_recorder_running(self):
        try:
            subprocess.check_output(["pgrep", "-x", "wf-recorder"])
            return True
        except subprocess.CalledProcessError:
            return False

    def check_recording_status(self):
        running = self.is_wf_recorder_running()
        if running:
            self.status_label.set_text("Recording Active...")
            self.status_label.set_name("recorder-status-active")
            self.buttons_box.set_visible(False)
            self.audio_toggle.set_visible(False)
            self.stop_btn.set_visible(True)
        else:
            self.status_label.set_text("Ready to Record")
            self.status_label.set_name("recorder-status")
            self.buttons_box.set_visible(True)
            self.audio_toggle.set_visible(True)
            self.stop_btn.set_visible(False)
        return True

    def on_start_recording(self, widget, select_area):
        if subprocess.run(["which", "wf-recorder"], capture_output=True).returncode != 0:
            subprocess.run(["notify-send", "Aiko Recorder", "wf-recorder is not installed!", "-i", "dialog-error"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return

        # Hide window during area selection / start to avoid capture
        self.hide()
        while Gtk.events_pending():
            Gtk.main_iteration()

        # Prep directory
        video_dir = os.path.expanduser("~/Videos")
        if not os.path.exists(video_dir):
            os.makedirs(video_dir)

        import datetime
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        output_file = os.path.join(video_dir, f"recording_{timestamp}.mp4")

        cmd = ["wf-recorder", "-f", output_file]

        if select_area:
            if subprocess.run(["which", "slurp"], capture_output=True).returncode != 0:
                subprocess.run(["notify-send", "Aiko Recorder", "slurp is not installed for area selection!", "-i", "dialog-error"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.show_all()
                return
            
            try:
                area = subprocess.check_output(["slurp"]).decode("utf-8").strip()
                cmd.extend(["-g", area])
            except subprocess.CalledProcessError:
                self.show_all()
                return

        if self.audio_toggle.get_active():
            cmd.append("-a")

        try:
            subprocess.Popen(cmd)
            subprocess.run(["notify-send", "Aiko Recorder", "Recording started...", "-i", "media-record"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            subprocess.run(["notify-send", "Aiko Recorder", f"Failed to start recording: {e}", "-i", "dialog-error"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self.show_all()
        self.check_recording_status()

    def on_stop_recording(self, widget):
        if self.is_wf_recorder_running():
            subprocess.run(["pkill", "-SIGINT", "-x", "wf-recorder"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["notify-send", "Aiko Recorder", "Recording stopped and saved to ~/Videos", "-i", "dialog-information"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.check_recording_status()

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
        AikoRecorder()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoRecorder: {e}")
        sys.exit(1)
