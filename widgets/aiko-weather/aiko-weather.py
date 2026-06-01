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

        # Weather icons mapping (Nerd Font)
        # WMO Code mapping for Open-Meteo
        self.wmo_icons = {
            0: "", 1: "", 2: "", 3: "",
            45: "", 48: "",
            51: "", 53: "", 55: "",
            56: "", 57: "",
            61: "", 63: "", 65: "",
            66: "", 67: "",
            71: "", 73: "", 75: "", 77: "",
            80: "", 81: "", 82: "",
            85: "", 86: "",
            95: "", 96: "", 99: ""
        }
        
        # wttr.in mapping (for legacy cache support)
        self.wttr_icons = {
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

        # WMO Descriptions
        self.wmo_desc = {
            0: "Clear Sky", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast",
            45: "Fog", 48: "Rime Fog",
            51: "Light Drizzle", 53: "Moderate Drizzle", 55: "Dense Drizzle",
            61: "Slight Rain", 63: "Moderate Rain", 65: "Heavy Rain",
            71: "Slight Snow", 73: "Moderate Snow", 75: "Heavy Snow",
            80: "Rain Showers", 81: "Moderate Showers", 82: "Violent Showers",
            95: "Thunderstorm"
        }

        # Load CSS
        self.load_css()

        # Layout
        self.vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.vbox.set_margin_top(25)
        self.vbox.set_margin_bottom(25)
        self.vbox.set_margin_start(25)
        self.vbox.set_margin_end(25)
        self.add(self.vbox)

        # Current Weather Section
        header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        self.vbox.pack_start(header_hbox, False, False, 0)

        self.current_icon = Gtk.Label(label="")
        self.current_icon.set_name("weather-large-icon")
        header_hbox.pack_start(self.current_icon, False, False, 0)

        temp_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
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

        # Separator Line (Restore)
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

        # Load from cache first
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
                    if 'current_condition' in data: # wttr.in format
                        self.apply_wttr_data(data)
                    else: # open-meteo format
                        self.apply_meteo_data(data)
            except Exception as e:
                print(f"Cache error: {e}")

    def update_weather(self):
        thread = threading.Thread(target=self.fetch_weather_data)
        thread.daemon = True
        thread.start()
        return True

    def fetch_weather_data(self):
        cache_file = os.path.expanduser("~/.cache/aiko-weather.json")
        
        # Try Open-Meteo first (more reliable)
        try:
            # 1. Get Location
            with urllib.request.urlopen("http://ip-api.com/json/?fields=lat,lon,city", timeout=5) as loc_url:
                loc_data = json.loads(loc_url.read().decode())
                lat, lon = loc_data.get('lat'), loc_data.get('lon')
                city = loc_data.get('city', 'Unknown')

            # 2. Get Weather
            meteo_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,apparent_temperature,weather_code&daily=weather_code,temperature_2m_max&timezone=auto&forecast_days=3"
            with urllib.request.urlopen(meteo_url, timeout=5) as url:
                data = json.loads(url.read().decode())
                data['city'] = city # Add city to data
                
                # Save to cache
                try:
                    os.makedirs(os.path.dirname(cache_file), exist_ok=True)
                    with open(cache_file, 'w') as f:
                        json.dump(data, f)
                except: pass

                GLib.idle_add(self.apply_meteo_data, data)
                return
        except Exception as e:
            print(f"Meteo error: {e}")

        # Fallback to wttr.in
        try:
            with urllib.request.urlopen("https://wttr.in/?format=j1", timeout=5) as url:
                data = json.loads(url.read().decode())
                # Save to cache
                try:
                    os.makedirs(os.path.dirname(cache_file), exist_ok=True)
                    with open(cache_file, 'w') as f:
                        json.dump(data, f)
                except: pass
                GLib.idle_add(self.apply_wttr_data, data)
                return
        except Exception as e:
            print(f"wttr error: {e}")
            GLib.idle_add(self.handle_error)

    def handle_error(self):
        if self.current_desc.get_text() == "Loading...":
            self.current_desc.set_text("Offline")
            self.feels_like.set_text("Check connection")
        else:
            txt = self.current_desc.get_text()
            if "(Offline)" not in txt:
                self.current_desc.set_text(f"{txt} (Offline)")

    def apply_meteo_data(self, data):
        try:
            current = data['current']
            code = current['weather_code']
            
            self.current_icon.set_text(self.wmo_icons.get(code, ""))
            self.current_temp.set_text(f"{round(current['temperature_2m'])}°C")
            self.current_desc.set_text(self.wmo_desc.get(code, "Unknown"))
            self.feels_like.set_text(f"Feels like {round(current['apparent_temperature'])}°C")

            # Forecast
            for child in self.forecast_list.get_children():
                self.forecast_list.remove(child)

            for i in range(3):
                date_str = data['daily']['time'][i]
                date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                day_name = date_obj.strftime('%a')
                day_code = data['daily']['weather_code'][i]
                day_temp = data['daily']['temperature_2m_max'][i]

                self.add_forecast_row(day_name, self.wmo_icons.get(day_code, ""), f"{round(day_temp)}°C")
            
            self.show_all()
        except Exception as e:
            print(f"Meteo apply error: {e}")
            self.handle_error()

    def apply_wttr_data(self, data):
        try:
            current = data['current_condition'][0]
            code = current['weatherCode']
            
            self.current_icon.set_text(self.wttr_icons.get(code, ""))
            self.current_temp.set_text(f"{current['temp_C']}°C")
            self.current_desc.set_text(current['weatherDesc'][0]['value'])
            self.feels_like.set_text(f"Feels like {current['FeelsLikeC']}°C")

            for child in self.forecast_list.get_children():
                self.forecast_list.remove(child)

            for day in data['weather'][:3]:
                date_obj = datetime.strptime(day['date'], '%Y-%m-%d')
                day_name = date_obj.strftime('%a')
                icon = self.wttr_icons.get(day['hourly'][4]['weatherCode'], "")
                self.add_forecast_row(day_name, icon, f"{day['avgtempC']}°C")
            
            self.show_all()
        except Exception as e:
            print(f"wttr apply error: {e}")
            self.handle_error()

    def add_forecast_row(self, day, icon, temp):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.set_margin_top(8)
        row.set_margin_bottom(8)
        
        day_lbl = Gtk.Label(label=day)
        day_lbl.set_name("forecast-day")
        day_lbl.set_size_request(60, -1)
        day_lbl.set_halign(Gtk.Align.START)
        
        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.set_name("forecast-icon")
        
        temp_lbl = Gtk.Label(label=temp)
        temp_lbl.set_name("forecast-temp")
        temp_lbl.set_halign(Gtk.Align.END)
        # Add a small end margin so it's not touching the border
        temp_lbl.set_margin_end(5)
        
        row.pack_start(day_lbl, False, False, 0)
        row.pack_start(icon_lbl, True, True, 0)
        row.pack_end(temp_lbl, False, False, 0)
        
        self.forecast_list.add(row)

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

    def load_css(self):
        css_provider = Gtk.CssProvider()
        # Use theme.css symlink for dynamic switching
        theme_path = os.path.join(self.script_dir, "theme.css")
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
