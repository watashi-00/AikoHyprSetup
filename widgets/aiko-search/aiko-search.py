#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, Pango, GdkPixbuf

# Force dark theme variant
settings = Gtk.Settings.get_default()
if settings:
    settings.set_property("gtk-application-prefer-dark-theme", True)

import os
import sys
import re
import subprocess
import urllib.request
import urllib.parse
import json
import threading

class AikoSearch(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Search")
        self.set_name("aiko-search-window")
        self.set_default_size(600, 400)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_keep_above(True)

        # Search variables
        self.search_mode = "default"  # default, google, youtube, wiki, files
        self.apps = self.load_installed_apps()
        self.theme_name = "pink-anime"
        self.accent_color = "#ff8fbd"
        self.current_search_query = ""

        # Load dynamic theme CSS
        self.load_css()

        # Layout
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.main_box.set_name("main-container")
        self.add(self.main_box)

        # Search Bar Box
        self.search_bar_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.search_bar_box.set_name("search-bar-box")
        self.search_bar_box.set_margin_start(15)
        self.search_bar_box.set_margin_end(15)
        self.search_bar_box.set_margin_top(15)
        self.search_bar_box.set_margin_bottom(15)
        self.main_box.pack_start(self.search_bar_box, False, False, 0)

        # Search Icon
        self.search_icon = Gtk.Label()
        self.search_icon.set_markup("<span size='large'>🔍</span>")
        self.search_bar_box.pack_start(self.search_icon, False, False, 0)

        # Badge Label (Hidden initially)
        self.badge_label = Gtk.Label()
        self.badge_label.set_name("search-badge")
        self.badge_label.set_no_show_all(True)
        self.badge_label.hide()
        self.search_bar_box.pack_start(self.badge_label, False, False, 0)

        # Entry Field
        self.entry = Gtk.Entry()
        self.entry.set_name("search-entry")
        self.entry.set_has_frame(False)
        self.entry.set_hexpand(True)
        self.entry.set_placeholder_text("Search apps, files (f:), YouTube (yt:)...")
        self.entry.connect("changed", self.on_entry_changed)
        self.entry.connect("key-press-event", self.on_entry_key_press)
        self.search_bar_box.pack_start(self.entry, True, True, 0)

        # Close Button
        self.close_btn = Gtk.Button(label="✕")
        self.close_btn.set_name("close-button")
        self.close_btn.connect("clicked", lambda w: self.destroy())
        self.search_bar_box.pack_end(self.close_btn, False, False, 0)

        # Separator line
        self.separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        self.separator.set_name("search-separator")
        self.main_box.pack_start(self.separator, False, False, 0)

        # Scrolled Area for Results
        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_name("results-scrolled")
        self.scrolled.set_hexpand(True)
        self.scrolled.set_vexpand(True)
        self.scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.main_box.pack_start(self.scrolled, True, True, 0)

        # ListBox for items
        self.listbox = Gtk.ListBox()
        self.listbox.set_name("results-listbox")
        self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.listbox.connect("row-activated", self.on_row_activated)
        self.scrolled.add(self.listbox)

        # Connect window events
        self.connect("key-press-event", self.on_window_key_press)

        # Initial populate
        self.update_results("")

        self.show_all()
        self.entry.grab_focus()

    def get_prefix_info(self, text):
        # Match keys followed by space or colon
        match = re.match(r'^(g:|google:|yt:|youtube:|w:|wiki:|f:|files:)\s*(.*)$', text, re.IGNORECASE)
        if match:
            key = match.group(1).lower().rstrip(':').strip()
            query = match.group(2)
            if key in ("g", "google"):
                return "google", "Google", query
            elif key in ("yt", "youtube"):
                return "youtube", "YouTube", query
            elif key in ("w", "wiki"):
                return "wiki", "Wikipedia", query
            elif key in ("f", "files"):
                return "files", "Files", query
        return None

    def get_prefix_text(self, mode):
        if mode == "google": return "g: "
        elif mode == "youtube": return "yt: "
        elif mode == "wiki": return "w: "
        elif mode == "files": return "f: "
        return ""

    def on_entry_changed(self, entry):
        text = entry.get_text()
        
        # If in default mode, check if we entered a prefix
        if self.search_mode == "default":
            info = self.get_prefix_info(text)
            if info:
                mode, label, query = info
                self.search_mode = mode
                self.badge_label.set_text(label)
                self.badge_label.show()
                # Clear prefix from input text so user edits query directly
                self.entry.set_text(query)
                self.entry.set_position(len(query))
                self.update_results(query)
                return

        self.update_results(text)

    def clear_search_mode(self):
        self.search_mode = "default"
        self.badge_label.hide()
        self.badge_label.set_text("")

    def on_entry_key_press(self, entry, event):
        # Backspace in empty field clears active mode
        if event.keyval == Gdk.KEY_BackSpace and entry.get_text() == "" and self.search_mode != "default":
            prefix = self.get_prefix_text(self.search_mode)
            self.clear_search_mode()
            entry.set_text(prefix)
            entry.set_position(len(prefix))
            return True
        
        # Up/Down arrow keys move listbox selection
        if event.keyval == Gdk.KEY_Down:
            self.move_selection(1)
            return True
        elif event.keyval == Gdk.KEY_Up:
            self.move_selection(-1)
            return True
        # Return activates selection
        elif event.keyval == Gdk.KEY_Return:
            self.activate_selection()
            return True
            
        return False

    def on_window_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
            return True
        return False

    def move_selection(self, step):
        rows = self.listbox.get_children()
        if not rows:
            return
        selected = self.listbox.get_selected_row()
        if not selected:
            self.listbox.select_row(rows[0])
        else:
            idx = rows.index(selected)
            new_idx = max(0, min(len(rows) - 1, idx + step))
            self.listbox.select_row(rows[new_idx])
            # Scroll to make selected visible
            row = rows[new_idx]
            adj = self.scrolled.get_vadjustment()
            alloc = row.get_allocation()
            adj.set_value(alloc.y - 10)

    def activate_selection(self):
        selected = self.listbox.get_selected_row()
        if selected:
            selected.activate()

    def update_results(self, query):
        # Clear list
        for child in self.listbox.get_children():
            self.listbox.remove(child)

        query = query.strip()
        self.current_search_query = query

        if self.search_mode == "default":
            # Search apps
            matches = []
            if not query:
                # Show top 5 standard apps initially
                matches = self.apps[:5]
            else:
                for app in self.apps:
                    if query.lower() in app["name"].lower() or query.lower() in app["comment"].lower():
                        matches.append(app)
                        if len(matches) >= 6:
                            break

            for app in matches:
                self.add_app_row(app)

            # Search files quickly if query has at least 3 characters
            if query and len(query) >= 3:
                files = self.find_files(query)
                for f_path in files[:3]:
                    self.add_file_row(f_path)

            # Add fallback search action rows if query exists
            if query:
                self.add_search_action_row("google", f"Search Google for '{query}'", query)
                self.add_search_action_row("youtube", f"Search YouTube for '{query}'", query)

        elif self.search_mode == "files":
            if not query:
                self.add_info_row("Type to search files in your home directory...")
            else:
                files = self.find_files(query)
                if not files:
                    self.add_info_row(f"No files found matching '{query}'")
                else:
                    for f_path in files:
                        self.add_file_row(f_path)

        else:
            # Web search modes (google, youtube, wiki)
            if not query:
                self.add_info_row(f"Type to search on {self.search_mode.capitalize()}...")
            else:
                label_text = f"Search {self.search_mode.capitalize()} for '{query}'"
                self.add_search_action_row(self.search_mode, label_text, query)
                
                # Fetch autocomplete suggestions / search videos dynamically
                if self.search_mode == "google":
                    self.fetch_suggestions_async(self.search_mode, query)
                elif self.search_mode == "youtube":
                    self.fetch_youtube_search_async(query)

        self.listbox.show_all()
        # Default select first row
        rows = self.listbox.get_children()
        if rows:
            self.listbox.select_row(rows[0])

    def add_app_row(self, app):
        row = Gtk.ListBoxRow()
        row.set_name("result-row")
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(8)
        hbox.set_margin_bottom(8)
        row.add(hbox)

        # Image
        img = Gtk.Image.new_from_icon_name(app["icon"], Gtk.IconSize.LARGE_TOOLBAR)
        hbox.pack_start(img, False, False, 0)

        # Labels
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hbox.pack_start(vbox, True, True, 0)

        name_lbl = Gtk.Label()
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.set_name("row-title")
        name_lbl.set_markup(f"<span foreground='{self.accent_color}' weight='bold'>App:</span> {app['name']}")
        vbox.pack_start(name_lbl, False, False, 0)

        if app["comment"]:
            desc_lbl = Gtk.Label(label=app["comment"])
            desc_lbl.set_halign(Gtk.Align.START)
            desc_lbl.set_name("row-subtitle")
            vbox.pack_start(desc_lbl, False, False, 0)

        # Action payload
        row.action = lambda: self.launch_app(app["exec"])
        self.listbox.add(row)

    def add_file_row(self, path):
        row = Gtk.ListBoxRow()
        row.set_name("result-row")
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(8)
        hbox.set_margin_bottom(8)
        row.add(hbox)

        # Icon
        img = Gtk.Image.new_from_icon_name("text-x-generic", Gtk.IconSize.LARGE_TOOLBAR)
        hbox.pack_start(img, False, False, 0)

        # Labels
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hbox.pack_start(vbox, True, True, 0)

        name_lbl = Gtk.Label()
        name_lbl.set_halign(Gtk.Align.START)
        name_lbl.set_name("row-title")
        basename = os.path.basename(path)
        name_lbl.set_markup(f"<span foreground='{self.accent_color}' weight='bold'>File:</span> {basename}")
        vbox.pack_start(name_lbl, False, False, 0)

        # Short path
        short_path = path.replace(os.path.expanduser("~"), "~")
        desc_lbl = Gtk.Label(label=short_path)
        desc_lbl.set_halign(Gtk.Align.START)
        desc_lbl.set_name("row-subtitle")
        vbox.pack_start(desc_lbl, False, False, 0)

        row.action = lambda: self.open_target(path)
        self.listbox.add(row)

    def add_search_action_row(self, mode, text, query, is_suggestion=False):
        row = Gtk.ListBoxRow()
        row.set_name("result-row")
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(10)
        hbox.set_margin_bottom(10)
        row.add(hbox)

        # Icon
        icon_name = "system-search"
        if mode == "youtube": icon_name = "video-x-generic"
        elif mode == "wiki": icon_name = "accessory-dictionary"
        img = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
        hbox.pack_start(img, False, False, 0)

        lbl = Gtk.Label()
        lbl.set_halign(Gtk.Align.START)
        lbl.set_name("row-title")
        
        mode_label = "YouTube" if mode == "youtube" else ("Wikipedia" if mode == "wiki" else mode.capitalize())
        if is_suggestion:
            lbl.set_markup(f"<span foreground='{self.accent_color}' weight='bold'>{mode_label} Suggestion:</span> {text}")
        else:
            lbl.set_markup(f"<span foreground='{self.accent_color}' weight='bold'>{mode_label}:</span> Search for <i>{query}</i>")
            
        hbox.pack_start(lbl, True, True, 0)

        # Search url dispatch
        target_query = text if is_suggestion else query
        url = ""
        if mode == "google":
            url = f"https://www.google.com/search?q={urllib.parse.quote_plus(target_query)}"
        elif mode == "youtube":
            url = f"https://www.youtube.com/results?search_query={urllib.parse.quote_plus(target_query)}"
        elif mode == "wiki":
            url = f"https://en.wikipedia.org/wiki/Special:Search?search={urllib.parse.quote_plus(target_query)}"

        row.action = lambda: self.open_target(url)
        self.listbox.add(row)

    def add_info_row(self, text):
        row = Gtk.ListBoxRow()
        row.set_name("info-row")
        row.set_selectable(False)
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hbox.set_margin_start(15)
        hbox.set_margin_top(12)
        hbox.set_margin_bottom(12)
        row.add(hbox)

        lbl = Gtk.Label(label=text)
        lbl.set_halign(Gtk.Align.START)
        lbl.set_name("info-label")
        hbox.pack_start(lbl, True, True, 0)

        row.action = lambda: None
        self.listbox.add(row)

    def fetch_suggestions_async(self, mode, query):
        def callback(suggestions):
            if self.current_search_query != query or not suggestions:
                return
            # Add unique suggestions
            for sug in suggestions[:5]:
                # Don't add if it's the exact same query
                if sug.strip().lower() == query.lower():
                    continue
                self.add_search_action_row(mode, sug, query, is_suggestion=True)
            self.listbox.show_all()

        def run():
            try:
                q = urllib.parse.quote(query)
                if mode == "google":
                    url = f"http://suggestqueries.google.com/complete/search?client=firefox&q={q}"
                elif mode == "youtube":
                    url = f"http://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q={q}"
                else:
                    return
                
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req, timeout=0.8) as response:
                    data = json.loads(response.read().decode('latin-1'))
                    suggestions = data[1] if len(data) > 1 else []
                    GLib.idle_add(callback, suggestions)
            except Exception:
                pass

        threading.Thread(target=run, daemon=True).start()

    def add_youtube_video_row(self, video_id, title, channel, duration, description):
        row = Gtk.ListBoxRow()
        row.set_name("result-row")
        
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(8)
        hbox.set_margin_bottom(8)
        row.add(hbox)

        # Image placeholder
        img = Gtk.Image.new_from_icon_name("video-x-generic", Gtk.IconSize.DIALOG)
        img.set_size_request(80, 60)
        hbox.pack_start(img, False, False, 0)

        # Text container
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hbox.pack_start(vbox, True, True, 0)

        # Title
        title_lbl = Gtk.Label()
        title_lbl.set_halign(Gtk.Align.START)
        title_lbl.set_name("row-title")
        title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
        escaped_title = GLib.markup_escape_text(title)
        title_lbl.set_markup(f"<span foreground='{self.accent_color}' weight='bold'>YT:</span> {escaped_title}")
        vbox.pack_start(title_lbl, False, False, 0)

        # Metadata
        meta_text = channel
        if duration:
            meta_text += f" • {duration}"
        meta_lbl = Gtk.Label(label=meta_text)
        meta_lbl.set_halign(Gtk.Align.START)
        meta_lbl.set_name("row-subtitle")
        vbox.pack_start(meta_lbl, False, False, 0)

        # Description
        if description:
            desc_lbl = Gtk.Label(label=description)
            desc_lbl.set_halign(Gtk.Align.START)
            desc_lbl.set_name("row-subtitle")
            desc_lbl.set_ellipsize(Pango.EllipsizeMode.END)
            desc_lbl.set_opacity(0.65)
            vbox.pack_start(desc_lbl, False, False, 0)

        url = f"https://www.youtube.com/watch?v={video_id}"
        row.action = lambda: self.open_target(url)
        self.listbox.add(row)
        
        # Load thumbnail asynchronously
        self.load_thumbnail_async(video_id, img)

    def load_thumbnail_async(self, video_id, gtk_image):
        thumb_path = f"/tmp/yt_thumb_{video_id}.jpg"
        
        def apply_image():
            if os.path.exists(thumb_path):
                try:
                    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(thumb_path, 80, 60, True)
                    gtk_image.set_from_pixbuf(pixbuf)
                except Exception:
                    pass

        def run():
            if not os.path.exists(thumb_path):
                try:
                    url = f"https://img.youtube.com/vi/{video_id}/default.jpg"
                    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(req, timeout=3) as response:
                        with open(thumb_path, "wb") as f:
                            f.write(response.read())
                except Exception:
                    return
            GLib.idle_add(apply_image)

        threading.Thread(target=run, daemon=True).start()

    def fetch_youtube_search_async(self, query):
        def callback(videos):
            if self.current_search_query != query or not videos:
                return
            for vid in videos:
                self.add_youtube_video_row(
                    video_id=vid["id"],
                    title=vid["title"],
                    channel=vid["channel"],
                    duration=vid["duration"],
                    description=vid["description"]
                )
            self.listbox.show_all()

        def run():
            try:
                url = f"https://www.youtube.com/results?search_query={urllib.parse.quote(query)}"
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})
                with urllib.request.urlopen(req, timeout=3) as response:
                    html = response.read().decode('utf-8', errors='ignore')
                    match = re.search(r'var ytInitialData\s*=\s*({.*?});</script>', html)
                    if not match:
                        return
                    data = json.loads(match.group(1))
                    
                    try:
                        contents = data['contents']['twoColumnSearchResultsRenderer']['primaryContents']['sectionListRenderer']['contents']
                        item_sec = contents[0]['itemSectionRenderer']
                        sec_contents = item_sec['contents']
                    except KeyError:
                        return

                    videos = []
                    for item in sec_contents:
                        if 'videoRenderer' in item:
                            vr = item['videoRenderer']
                            
                            video_id = vr.get('videoId')
                            if not video_id:
                                continue
                                
                            title = vr.get('title', {}).get('runs', [{}])[0].get('text', '')
                            channel = vr.get('ownerText', {}).get('runs', [{}])[0].get('text', '')
                            duration = vr.get('lengthText', {}).get('simpleText', '')
                            
                            desc = ''
                            if 'descriptionSnippet' in vr:
                                desc = ''.join([r.get('text', '') for r in vr['descriptionSnippet'].get('runs', [])])
                                
                            videos.append({
                                "id": video_id,
                                "title": title,
                                "channel": channel,
                                "duration": duration,
                                "description": desc
                            })
                            if len(videos) >= 5:
                                break
                    
                    GLib.idle_add(callback, videos)
            except Exception:
                pass

        threading.Thread(target=run, daemon=True).start()

    def on_row_activated(self, listbox, row):
        if hasattr(row, "action"):
            row.action()

    def launch_app(self, exec_cmd):
        try:
            subprocess.Popen(exec_cmd, shell=True, start_new_session=True)
        except Exception as e:
            print(f"Error launching app: {e}")
        self.destroy()
        sys.exit(0)

    def open_target(self, target):
        try:
            subprocess.Popen(["xdg-open", target])
        except Exception as e:
            print(f"Error opening target: {e}")
        self.destroy()
        sys.exit(0)

    def find_files(self, query):
        if len(query) < 3:
            return []
        try:
            # Fast shell query utilizing find limit to speed up results
            # Only search up to maxdepth 4 to keep it extremely fast and responsive during typing
            find_cmd = f"find ~ -maxdepth 4 -not -path '*/.*' -not -path '*/Cache*' -not -path '*/node_modules/*' -iname '*{query}*' -type f 2>/dev/null | head -n 4"
            output = subprocess.check_output(find_cmd, shell=True).decode("utf-8").strip()
            return [f for f in output.split("\n") if f]
        except Exception:
            return []

    def load_installed_apps(self):
        apps = []
        seen_names = set()
        dirs = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]
        for d in dirs:
            if not os.path.exists(d):
                continue
            for f in os.listdir(d):
                if not f.endswith(".desktop"):
                    continue
                path = os.path.join(d, f)
                try:
                    name, exec_cmd, icon, comment = None, None, None, ""
                    no_display = False
                    with open(path, "r", errors="ignore") as file:
                        in_desktop_entry = False
                        for line in file:
                            line = line.strip()
                            if line == "[Desktop Entry]":
                                in_desktop_entry = True
                            elif line.startswith("[") and line.endswith("]"):
                                in_desktop_entry = False
                            if not in_desktop_entry:
                                continue
                            
                            if line.startswith("Name="):
                                name = line.split("=", 1)[1]
                            elif line.startswith("Exec="):
                                exec_cmd = line.split("=", 1)[1]
                            elif line.startswith("Icon="):
                                icon = line.split("=", 1)[1]
                            elif line.startswith("Comment="):
                                comment = line.split("=", 1)[1]
                            elif line.startswith("NoDisplay="):
                                if line.split("=", 1)[1].lower() == "true":
                                    no_display = True
                    if name and exec_cmd and not no_display:
                        # Strip argument flags like %U, %f from Exec
                        exec_cmd = re.sub(r'%[fFuUiDd]', '', exec_cmd).strip()
                        if name not in seen_names:
                            apps.append({
                                "name": name,
                                "exec": exec_cmd,
                                "icon": icon or "application-x-executable",
                                "comment": comment
                            })
                            seen_names.add(name)
                except Exception:
                    pass
        apps.sort(key=lambda x: x["name"].lower())
        return apps

    def load_css(self):
        css_provider = Gtk.CssProvider()
        
        # Determine theme name and accent color
        self.theme_name = "pink-anime"
        self.accent_color = "#ff8fbd"
        waybar_style = os.path.expanduser("~/.config/waybar/style.css")
        if os.path.islink(waybar_style):
            target = os.readlink(waybar_style)
            if "black-white" in target:
                self.theme_name = "black-white"
                self.accent_color = "#ffffff"
            elif "cyber-blue" in target:
                self.theme_name = "cyber-blue"
                self.accent_color = "#00ffff"

        theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes", f"{self.theme_name}.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

if __name__ == "__main__":
    AikoSearch()
    Gtk.main()
