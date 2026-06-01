import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf, Pango
import os
import sys
import subprocess
import threading
import urllib.request
from io import BytesIO

class AikoPlayer(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Player")
        
        self.set_name("aiko-player")
        self.set_role("aiko-player")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Enforce fixed size
        self.set_default_size(480, 260)
        self.set_size_request(480, 260)

        # Paths
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        
        # Load CSS
        self.load_css()

        # Layout
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.main_vbox.set_margin_top(25)
        self.main_vbox.set_margin_bottom(20)
        self.main_vbox.set_margin_start(25)
        self.main_vbox.set_margin_end(25)
        self.add(self.main_vbox)

        # Upper Section (Art + Info)
        self.upper_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=25)
        self.main_vbox.pack_start(self.upper_hbox, False, False, 0)

        # Album Art
        self.art_image = Gtk.Image()
        self.art_image.set_name("player-art")
        self.art_image.set_size_request(160, 160)
        self.upper_hbox.pack_start(self.art_image, False, False, 0)

        # Info VBox
        self.info_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.info_vbox.set_valign(Gtk.Align.CENTER)
        self.upper_hbox.pack_start(self.info_vbox, True, True, 0)

        self.title_label = Gtk.Label(label="No Title")
        self.title_label.set_name("player-title")
        self.title_label.set_halign(Gtk.Align.START)
        self.title_label.set_ellipsize(Pango.EllipsizeMode.END)
        self.title_label.set_max_width_chars(20) # Prevent stretching
        self.info_vbox.pack_start(self.title_label, False, False, 0)

        self.artist_label = Gtk.Label(label="Unknown Artist")
        self.artist_label.set_name("player-artist")
        self.artist_label.set_halign(Gtk.Align.START)
        self.artist_label.set_ellipsize(Pango.EllipsizeMode.END)
        self.artist_label.set_max_width_chars(25)
        self.info_vbox.pack_start(self.artist_label, False, False, 0)

        self.album_label = Gtk.Label(label="Unknown Album")
        self.album_label.set_name("player-album")
        self.album_label.set_halign(Gtk.Align.START)
        self.album_label.set_ellipsize(Pango.EllipsizeMode.END)
        self.album_label.set_max_width_chars(25)
        self.info_vbox.pack_start(self.album_label, False, False, 0)

        # Heart Icon (Right side of info)
        self.heart_label = Gtk.Label(label="♥")
        self.heart_label.set_name("player-heart")
        self.heart_label.set_valign(Gtk.Align.CENTER)
        self.upper_hbox.pack_end(self.heart_label, False, False, 0)

        # Progress Section
        self.progress_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.main_vbox.pack_start(self.progress_hbox, False, False, 5)

        self.time_label = Gtk.Label(label="0:00")
        self.time_label.set_name("player-time")
        self.progress_hbox.pack_start(self.time_label, False, False, 0)

        self.progress_bar = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.progress_bar.set_name("player-progress")
        self.progress_bar.set_draw_value(False)
        self.progress_bar.connect("change-value", self.on_seek)
        self.progress_hbox.pack_start(self.progress_bar, True, True, 0)

        self.duration_label = Gtk.Label(label="0:00")
        self.duration_label.set_name("player-time")
        self.progress_hbox.pack_start(self.duration_label, False, False, 0)

        # Controls Section
        self.controls_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=25)
        self.controls_hbox.set_halign(Gtk.Align.CENTER)
        self.main_vbox.pack_start(self.controls_hbox, False, False, 0)

        self.prev_btn = Gtk.Button(label="󰒫")
        self.prev_btn.set_name("player-btn-small")
        self.prev_btn.connect("clicked", lambda x: self.run_playerctl("previous"))
        self.controls_hbox.pack_start(self.prev_btn, False, False, 0)

        self.play_btn = Gtk.Button(label="󰐊")
        self.play_btn.set_name("player-btn-main")
        self.play_btn.connect("clicked", lambda x: self.run_playerctl("play-pause"))
        self.controls_hbox.pack_start(self.play_btn, False, False, 0)

        self.next_btn = Gtk.Button(label="󰒬")
        self.next_btn.set_name("player-btn-small")
        self.next_btn.connect("clicked", lambda x: self.run_playerctl("next"))
        self.controls_hbox.pack_start(self.next_btn, False, False, 0)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        # State
        self.current_art_url = ""
        self.is_seeking = False

        # Start Update Loop
        GLib.timeout_add(1000, self.update_info)
        
        self.show_all()

    def run_playerctl(self, command):
        subprocess.run(["playerctl", command])
        self.update_info()

    def on_seek(self, scale, scroll, value):
        self.run_playerctl(f"position {value}")
        return False

    def update_info(self):
        try:
            # Metadata
            title = subprocess.check_output(["playerctl", "metadata", "title"], stderr=subprocess.DEVNULL).decode().strip()
            artist = subprocess.check_output(["playerctl", "metadata", "artist"], stderr=subprocess.DEVNULL).decode().strip()
            album = subprocess.check_output(["playerctl", "metadata", "album"], stderr=subprocess.DEVNULL).decode().strip()
            art_url = subprocess.check_output(["playerctl", "metadata", "mpris:artUrl"], stderr=subprocess.DEVNULL).decode().strip()
            status = subprocess.check_output(["playerctl", "status"], stderr=subprocess.DEVNULL).decode().strip()
            
            # Position/Duration
            pos = float(subprocess.check_output(["playerctl", "position"], stderr=subprocess.DEVNULL).decode().strip())
            dur = float(subprocess.check_output(["playerctl", "metadata", "mpris:length"], stderr=subprocess.DEVNULL).decode().strip()) / 1000000

            self.title_label.set_text(title or "No Title")
            self.artist_label.set_text(artist or "Unknown Artist")
            self.album_label.set_text(album or "Unknown Album")
            
            # Update Play/Pause Icon
            self.play_btn.set_label("󰏤" if status == "Playing" else "󰐊")

            # Update Progress
            if not self.is_seeking:
                self.progress_bar.set_range(0, dur)
                self.progress_bar.set_value(pos)
                self.time_label.set_text(self.format_time(pos))
                self.duration_label.set_text(self.format_time(dur))

            # Update Art if changed
            if art_url != self.current_art_url:
                self.current_art_url = art_url
                threading.Thread(target=self.load_art, args=(art_url,)).start()

        except:
            self.title_label.set_text("Nothing Playing")
            self.artist_label.set_text("")
            self.album_label.set_text("")

        return True

    def format_time(self, seconds):
        m, s = divmod(int(seconds), 60)
        return f"{m}:{s:02d}"

    def load_art(self, url):
        if not url: return
        try:
            if url.startswith("file://"):
                path = url[7:]
            else:
                # Handle URLs (Spotify uses URLs)
                with urllib.request.urlopen(url) as response:
                    data = response.read()
                    loader = GdkPixbuf.PixbufLoader()
                    loader.write(data)
                    loader.close()
                    pixbuf = loader.get_pixbuf()
                    self.apply_art(pixbuf)
                    return

            pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
            self.apply_art(pixbuf)
        except Exception as e:
            print(f"Error loading art: {e}")

    def apply_art(self, pixbuf):
        if not pixbuf: return
        # Scale to 160x160
        scaled = pixbuf.scale_simple(160, 160, GdkPixbuf.InterpType.BILINEAR)
        GLib.idle_add(self.art_image.set_from_pixbuf, scaled)

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        theme_path = os.path.join(self.script_dir, "theme.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    from gi.repository import Pango
    try:
        AikoPlayer()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoPlayer: {e}")
        sys.exit(1)
