import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import os
import sys
import json
import urllib.request
import threading
from datetime import datetime

class AikoWeather(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Weather")
        
        # Identity for Hyprland rules
        self.set_name("aiko-weather")
        self.set_role("aiko-weather")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(250, 350)

        # Weather icons mapping (wttr.in codes to Nerd Font)
        self.icons = {
            "113": "", "116": "", "119": "", "122": "",
            "143": "", "176": "", "179": "", "182": "",
            "185": "", "200": "", "227": "", "230": "",
            "248": "", "260": "", "263": "", "266": "",
            "281": "", "284": "", "293": "", "296": "",
            "299": "", "302": "", "305": "", "308": "",
            "311": "", "314": "", "317": "", "320": "",
            "323": "", "326": "", "329": "", "332": "",
            "335": "", "338": "", "350": "", "353": "",
            "356": "", "359": "", "362": "", "365": "",
            "368": "", "371": "", "374": "", "377": "",
            "386": "", "389": "", "392": "", "395": ""
        }

        # Load CSS
        self.load_css()

        # Layout
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.vbox.set_margin_top(20)
        self.vbox.set_margin_bottom(20)
        self.vbox.set_margin_start(20)
        self.vbox.set_margin_end(20)
        self.add(self.vbox)

        # Current Weather Section
        header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        self.vbox.pack_start(header_hbox, False, False, 0)

        self.current_icon = Gtk.Label(label="")
        self.current_icon.set_name("weather-large-icon")
        header_hbox.pack_start(self.current_icon, False, False, 0)

        temp_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        header_hbox.pack_start(temp_vbox, True, True, 0)

        self.current_temp = Gtk.Label(label="--°C")
        self.current_temp.set_name("weather-current-temp")
        self.current_temp.set_halign(Gtk.Align.START)
        temp_vbox.pack_start(self.current_temp, False, False, 0)

        self.current_desc = Gtk.Label(label="Loading...")
        self.current_desc.set_name("weather-current-desc")
        self.current_desc.set_halign(Gtk.Align.START)
        temp_vbox.pack_start(self.current_desc, False, False, 0)

        self.feels_like = Gtk.Label(label="Please wait")
        self.feels_like.set_name("weather-feels-like")
        self.feels_like.set_halign(Gtk.Align.START)
        self.vbox.pack_start(self.feels_like, False, False, 0)

        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        self.vbox.pack_start(sep, False, False, 5)

        # Forecast Section
        self.forecast_list = Gtk.ListBox()
        self.forecast_list.set_name("weather-forecast-list")
        self.forecast_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.vbox.pack_start(self.forecast_list, True, True, 0)

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

        # Load from cache first to avoid "Loading..."
        self.load_cache()

        # Initial Fetch (Async)
        self.update_weather()
        
        # Refresh every 30 minutes
        GLib.timeout_add_seconds(1800, self.update_weather)

    def load_cache(self):
        cache_file = os.path.expanduser("~/.cache/aiko-weather.json")
        if os.path.exists(cache_file):
            try:
                with open(cache_file, 'r') as f:
                    data = json.load(f)
                    self.apply_weather_data(data)
            except Exception as e:
                print(f"Cache error: {e}")

    def update_weather(self):
        thread = threading.Thread(target=self.fetch_weather_data)
        thread.daemon = True
        thread.start()
        return True

    def fetch_weather_data(self):
        cache_file = os.path.expanduser("~/.cache/aiko-weather.json")
        try:
            # Try fetching from wttr.in
            with urllib.request.urlopen("https://wttr.in/?format=j1", timeout=10) as url:
                data = json.loads(url.read().decode())
                
                # Save to cache
                try:
                    os.makedirs(os.path.dirname(cache_file), exist_ok=True)
                    with open(cache_file, 'w') as f:
                        json.dump(data, f)
                except Exception as cache_err:
                    print(f"Failed to save cache: {cache_err}")

                GLib.idle_add(self.apply_weather_data, data)
        except Exception as e:
            print(f"Weather error: {e}")
            GLib.idle_add(self.handle_error)

    def handle_error(self):
        # Update UI if still on loading state or to show offline status
        if self.current_desc.get_text() == "Loading...":
            self.current_desc.set_text("Offline")
            self.feels_like.set_text("Check connection")
            self.current_temp.set_text("--°C")
        else:
            # If we have data (from cache), maybe just append (Offline) to desc
            current_text = self.current_desc.get_text()
            if "(Offline)" not in current_text:
                self.current_desc.set_text(f"{current_text} (Offline)")

    def apply_weather_data(self, data):
        try:
            current = data['current_condition'][0]
            weather_code = current['weatherCode']
            
            # Update UI
            self.current_icon.set_text(self.icons.get(weather_code, ""))
            self.current_temp.set_text(f"{current['temp_C']}°C")
            self.current_desc.set_text(current['weatherDesc'][0]['value'])
            self.feels_like.set_text(f"Feels like {current['FeelsLikeC']}°C")

            # Clear and Update Forecast
            for child in self.forecast_list.get_children():
                self.forecast_list.remove(child)

            for day in data['weather'][:3]:
                date_obj = datetime.strptime(day['date'], '%Y-%m-%d')
                day_name = date_obj.strftime('%a')
                
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                row.set_margin_top(5)
                row.set_margin_bottom(5)
                
                day_lbl = Gtk.Label(label=day_name)
                day_lbl.set_name("forecast-day")
                day_lbl.set_size_request(50, -1)
                day_lbl.set_halign(Gtk.Align.START)
                
                icon_lbl = Gtk.Label(label=self.icons.get(day['hourly'][4]['weatherCode'], ""))
                icon_lbl.set_name("forecast-icon")
                
                temp_lbl = Gtk.Label(label=f"{day['avgtempC']}°C")
                temp_lbl.set_name("forecast-temp")
                temp_lbl.set_halign(Gtk.Align.END)
                
                row.pack_start(day_lbl, False, False, 0)
                row.pack_start(icon_lbl, True, True, 0)
                row.pack_end(temp_lbl, False, False, 0)
                
                self.forecast_list.add(row)
            
            self.show_all()
        except (KeyError, IndexError) as e:
            print(f"Data format error: {e}")
            self.handle_error()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes", "pink-anime.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    try:
        AikoWeather()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoWeather: {e}")
        sys.exit(1)
