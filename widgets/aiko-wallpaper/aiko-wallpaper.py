import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib, GdkPixbuf, Pango
import os
import sys
import json
import subprocess
import threading
import hashlib
import time

class AikoWallpaper(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Wallpaper Engine")
        self.set_name("aiko-wallpaper-window")
        self.set_role("aiko-wallpaper")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(True)
        self.set_default_size(840, 600)
        
        # Load theme name and accent color
        self.load_theme_info()
        self.load_css()
        
        # Initial states
        self.wallpapers = []
        self.custom_dirs = []
        self.selected_wall = None
        self.selected_monitor = "ALL"
        
        self.load_custom_dirs_list()
        
        # Main container
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_box)
        
        # Styled container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.styled_container.set_name("main-container")
        self.main_box.pack_start(self.styled_container, True, True, 0)
        
        # Header bar
        self.create_header()
        
        # Main split content
        self.content_paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        self.content_paned.set_position(200)
        self.styled_container.pack_start(self.content_paned, True, True, 0)
        
        # Left sidebar (categories)
        self.create_sidebar()
        
        # Right area (wallpaper grid)
        self.create_grid_area()
        
        # Bottom controls
        self.create_bottom_bar()
        
        # Window settings
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Support transparency
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.set_visual(visual)
            
        # Start scanning in background
        self.start_indexing()
        
        self.show_all()

    def load_theme_info(self):
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
            elif "dynamic-wall" in target:
                self.theme_name = "dynamic-wall"
                # read accent from file
                try:
                    with open(waybar_style, 'r') as f:
                        for line in f:
                            if "@waybar_accent" in line:
                                parts = line.split(":")
                                if len(parts) > 1:
                                    self.accent_color = parts[1].replace(";","").strip()
                                    break
                except:
                    pass

    def load_css(self):
        css_provider = Gtk.CssProvider()
        theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes", f"{self.theme_name}.css")
        if not os.path.exists(theme_path):
            theme_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme.css")
        if os.path.exists(theme_path):
            css_provider.load_from_path(theme_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def load_custom_dirs_list(self):
        self.config_dir = os.path.expanduser("~/.config/waybar")
        self.dirs_file = os.path.join(self.config_dir, "wallpaper_dirs.txt")
        if os.path.exists(self.dirs_file):
            try:
                with open(self.dirs_file, 'r') as f:
                    self.custom_dirs = [line.strip() for line in f if line.strip() and os.path.exists(line.strip())]
            except:
                pass

    def save_custom_dirs_list(self):
        try:
            os.makedirs(self.config_dir, exist_ok=True)
            with open(self.dirs_file, 'w') as f:
                for d in self.custom_dirs:
                    f.write(f"{d}\n")
        except:
            pass

    def create_header(self):
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header_box.set_name("header-box")
        header_box.set_margin_top(12)
        header_box.set_margin_bottom(12)
        header_box.set_margin_start(16)
        header_box.set_margin_end(16)
        
        # Title
        title_label = Gtk.Label()
        title_label.set_markup(f"<span size='large' weight='bold' color='{self.accent_color}'>AIKO WALLPAPER ENGINE</span>")
        header_box.pack_start(title_label, False, False, 0)
        
        # Spacer
        spacer = Gtk.Box()
        header_box.pack_start(spacer, True, True, 0)
        
        # Monitor Selector
        mon_label = Gtk.Label(label="Target Monitor:")
        mon_label.set_name("monitor-label")
        header_box.pack_start(mon_label, False, False, 0)
        
        self.monitor_combo = Gtk.ComboBoxText()
        self.monitor_combo.set_name("monitor-combo")
        self.monitor_combo.append("ALL", "All Monitors")
        
        # Fetch monitors from Hyprland
        try:
            output = subprocess.check_output(["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL)
            monitors_data = json.loads(output)
            for m in monitors_data:
                name = m.get("name")
                if name:
                    self.monitor_combo.append(name, f"Monitor: {name}")
        except:
            # Fallbacks
            self.monitor_combo.append("eDP-1", "Monitor: eDP-1")
            self.monitor_combo.append("HDMI-A-1", "Monitor: HDMI-A-1")
            
        self.monitor_combo.set_active(0)
        self.monitor_combo.connect("changed", self.on_monitor_changed)
        header_box.pack_start(self.monitor_combo, False, False, 0)
        
        # Close Button
        close_btn = Gtk.Button(label="×")
        close_btn.set_name("close-button")
        close_btn.connect("clicked", lambda w: self.close())
        header_box.pack_start(close_btn, False, False, 0)
        
        self.styled_container.pack_start(header_box, False, False, 0)

    def create_sidebar(self):
        sidebar_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        sidebar_box.set_name("sidebar-box")
        sidebar_box.set_margin_top(10)
        sidebar_box.set_margin_bottom(10)
        sidebar_box.set_margin_start(10)
        sidebar_box.set_margin_end(10)
        
        # Category list
        self.category_list = Gtk.ListBox()
        self.category_list.set_name("category-list")
        self.category_list.connect("row-selected", self.on_category_selected)
        
        categories = [
            ("all", "All Backgrounds"),
            ("static", "Static Images"),
            ("video", "Videos & GIFs"),
            ("wpe", "Wallpaper Engine")
        ]
        
        for cat_id, cat_name in categories:
            row = Gtk.ListBoxRow()
            row.cat_id = cat_id
            lbl = Gtk.Label(label=cat_name, xalign=0)
            lbl.set_margin_start(8)
            lbl.set_margin_top(6)
            lbl.set_margin_bottom(6)
            row.add(lbl)
            self.category_list.add(row)
            
        sidebar_box.pack_start(self.category_list, True, True, 0)
        
        self.content_paned.pack1(sidebar_box, False, False)

    def create_grid_area(self):
        self.grid_scroll = Gtk.ScrolledWindow()
        self.grid_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.grid_scroll.set_name("grid-scroll")
        
        # FlowBox grid
        self.flowbox = Gtk.FlowBox()
        self.flowbox.set_valign(Gtk.Align.START)
        self.flowbox.set_max_children_per_line(6)
        self.flowbox.set_min_children_per_line(2)
        self.flowbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.flowbox.set_column_spacing(12)
        self.flowbox.set_row_spacing(12)
        self.flowbox.set_margin_top(16)
        self.flowbox.set_margin_bottom(16)
        self.flowbox.set_margin_start(16)
        self.flowbox.set_margin_end(16)
        self.flowbox.connect("child-activated", self.on_wallpaper_activated)
        self.flowbox.connect("selected-children-changed", self.on_selection_changed)
        
        self.grid_scroll.add(self.flowbox)
        self.content_paned.pack2(self.grid_scroll, True, True)

    def create_bottom_bar(self):
        bottom_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        bottom_box.set_name("bottom-box")
        bottom_box.set_margin_top(12)
        bottom_box.set_margin_bottom(12)
        bottom_box.set_margin_start(16)
        bottom_box.set_margin_end(16)
        
        # Add folder button
        add_dir_btn = Gtk.Button(label="+ Add Folder")
        add_dir_btn.set_name("add-folder-button")
        add_dir_btn.connect("clicked", self.on_add_folder_clicked)
        bottom_box.pack_start(add_dir_btn, False, False, 0)
        
        # Spacer
        spacer = Gtk.Box()
        bottom_box.pack_start(spacer, True, True, 0)
        
        # Apply Button
        self.apply_btn = Gtk.Button(label="Apply Wallpaper")
        self.apply_btn.set_name("apply-button")
        self.apply_btn.set_sensitive(False)
        self.apply_btn.connect("clicked", self.on_apply_clicked)
        bottom_box.pack_start(self.apply_btn, False, False, 0)
        
        self.styled_container.pack_start(bottom_box, False, False, 0)

    def start_indexing(self):
        # Scan standard paths + custom paths
        scan_threads = threading.Thread(target=self.index_wallpapers)
        scan_threads.daemon = True
        scan_threads.start()

    def index_wallpapers(self):
        # 1. Gather all directories to scan
        scan_paths = [
            os.path.expanduser("~/Pictures/Wallpapers"),
            os.path.expanduser("~/Pictures"),
            "/usr/share/backgrounds"
        ]
        # Wallpaper engine Workshop ID path
        wpe_workshop = os.path.expanduser("~/.local/share/Steam/steamapps/workshop/content/431960")
        if os.path.exists(wpe_workshop):
            scan_paths.append(wpe_workshop)
            
        for path in self.custom_dirs:
            if os.path.exists(path) and path not in scan_paths:
                scan_paths.append(path)
                
        # 2. Iterate and scan
        indexed_items = []
        static_exts = {".jpg", ".png", ".webp", ".jpeg"}
        video_exts = {".mp4", ".webm", ".gif", ".gifv", ".mkv", ".mov"}
        
        for path in scan_paths:
            if not os.path.exists(path):
                continue
            
            # WPE direct check
            if os.path.basename(path) == "431960":
                # Scan all workshop folders
                try:
                    for d in os.listdir(path):
                        wpe_dir = os.path.join(path, d)
                        if os.path.isdir(wpe_dir) and os.path.exists(os.path.join(wpe_dir, "project.json")):
                            indexed_items.append(self.parse_wpe_project(wpe_dir))
                except:
                    pass
                continue
                
            # Generic directory scan
            for root, dirs, files in os.walk(path):
                # Check if this subfolder is a Wallpaper Engine project
                if "project.json" in files:
                    indexed_items.append(self.parse_wpe_project(root))
                    # Prevent searching files inside the WPE folder recursively
                    dirs.clear()
                    continue
                    
                # Index files
                for f in files:
                    ext = os.path.splitext(f)[1].lower()
                    full_path = os.path.join(root, f)
                    if ext in static_exts:
                        indexed_items.append({
                            "type": "static",
                            "name": os.path.splitext(f)[0].replace("_", " ").title(),
                            "path": full_path,
                            "thumbnail": full_path
                        })
                    elif ext in video_exts:
                        indexed_items.append({
                            "type": "video",
                            "name": os.path.splitext(f)[0].replace("_", " ").title(),
                            "path": full_path,
                            "thumbnail": None
                        })
                        
        GLib.idle_add(self.display_wallpapers, indexed_items)

    def parse_wpe_project(self, root):
        json_path = os.path.join(root, "project.json")
        title = os.path.basename(root)
        wpe_type = "Scene"
        
        try:
            with open(json_path, 'r', errors='ignore') as f:
                data = json.load(f)
            title = data.get("title", title)
            wpe_type = data.get("type", "Scene")
        except:
            pass
            
        # Find thumbnail preview
        preview_img = None
        for pf in ["preview.jpg", "preview.png", "preview.gif", "preview.jpeg"]:
            p_path = os.path.join(root, pf)
            if os.path.exists(p_path):
                preview_img = p_path
                break
                
        return {
            "type": "wpe",
            "wpe_type": wpe_type,
            "name": title,
            "path": root,
            "thumbnail": preview_img
        }

    def display_wallpapers(self, items):
        self.wallpapers = items
        self.filter_and_render_grid()

    def filter_and_render_grid(self, category="all"):
        # Clear existing
        for child in self.flowbox.get_children():
            self.flowbox.remove(child)
            
        # Filter items
        filtered = []
        for item in self.wallpapers:
            if category == "all":
                filtered.append(item)
            elif category == "static" and item["type"] == "static":
                filtered.append(item)
            elif category == "video" and item["type"] == "video":
                filtered.append(item)
            elif category == "wpe" and item["type"] == "wpe":
                filtered.append(item)
                
        # Render cards
        for item in filtered:
            card = self.create_wallpaper_card(item)
            self.flowbox.add(card)
            
        self.show_all()

    def create_wallpaper_card(self, item):
        btn = Gtk.Button()
        btn.set_name("wallpaper-card")
        btn.wallpaper_data = item
        
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        btn.add(box)
        
        # Image preview
        img = Gtk.Image()
        img.set_name("card-image")
        box.pack_start(img, True, True, 0)
        
        # Async load thumbnail
        threading.Thread(target=self.load_thumbnail_async, args=(item, img)).start()
        
        # Title label
        lbl = Gtk.Label()
        lbl.set_name("card-title")
        lbl.set_text(item["name"])
        lbl.set_ellipsize(Pango.EllipsizeMode.END)
        lbl.set_max_width_chars(15)
        box.pack_start(lbl, False, False, 0)
        
        # Type badge
        badge = Gtk.Label()
        badge.set_name("card-badge")
        t_label = item["type"].upper()
        if item["type"] == "wpe":
            t_label = f"WPE: {item['wpe_type']}"
        badge.set_text(t_label)
        box.pack_start(badge, False, False, 0)
        
        return btn

    def load_thumbnail_async(self, item, gtk_image):
        thumb_path = item["thumbnail"]
        
        # If video, extract a thumbnail frame if ffmpeg is available
        if item["type"] == "video" and not thumb_path:
            h = hashlib.md5(item["path"].encode()).hexdigest()
            temp_thumb = f"/tmp/aiko_wall_thumb_{h}.jpg"
            if os.path.exists(temp_thumb):
                thumb_path = temp_thumb
            else:
                try:
                    cmd = ["ffmpeg", "-y", "-ss", "00:00:02", "-i", item["path"], "-vframes", "1", "-q:v", "5", temp_thumb]
                    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                    if os.path.exists(temp_thumb):
                        thumb_path = temp_thumb
                        item["thumbnail"] = temp_thumb
                except:
                    pass
                    
        # Apply preview/thumbnail image
        if thumb_path and os.path.exists(thumb_path):
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    thumb_path, 160, 90, True
                )
                GLib.idle_add(gtk_image.set_from_pixbuf, pixbuf)
                return
            except:
                pass
                
        # Default placeholder icon
        GLib.idle_add(self.set_placeholder_icon, gtk_image, item["type"])

    def set_placeholder_icon(self, gtk_image, type_name):
        icon_name = "image-x-generic"
        if type_name == "video":
            icon_name = "video-x-generic"
        elif type_name == "wpe":
            icon_name = "applications-other"
        
        theme = Gtk.IconTheme.get_default()
        try:
            pixbuf = theme.load_icon(icon_name, 64, 0)
            gtk_image.set_from_pixbuf(pixbuf)
        except:
            pass

    def on_category_selected(self, listbox, row):
        if row:
            self.filter_and_render_grid(row.cat_id)

    def on_selection_changed(self, flowbox):
        selected = flowbox.get_selected_children()
        if selected:
            card = selected[0].get_child()
            self.selected_wall = card.wallpaper_data
            self.apply_btn.set_sensitive(True)
        else:
            self.selected_wall = None
            self.apply_btn.set_sensitive(False)

    def on_wallpaper_activated(self, flowbox, child):
        card = child.get_child()
        self.selected_wall = card.wallpaper_data
        self.apply_btn.set_sensitive(True)
        self.on_apply_clicked(None)

    def on_monitor_changed(self, combo):
        self.selected_monitor = combo.get_active_id() or "ALL"

    def on_add_folder_clicked(self, widget):
        dialog = Gtk.FileChooserDialog(
            title="Choose a wallpaper folder",
            parent=self,
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_OPEN, Gtk.ResponseType.OK
        )
        
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            folder_path = dialog.get_filename()
            if folder_path and folder_path not in self.custom_dirs:
                self.custom_dirs.append(folder_path)
                self.save_custom_dirs_list()
                # Rescan
                self.start_indexing()
        dialog.destroy()

    def on_apply_clicked(self, widget):
        if not self.selected_wall:
            return
            
        wall_path = self.selected_wall["path"]
        monitor = self.selected_monitor
        
        # 1. Update wallpaper.conf state
        state_file = os.path.expanduser("~/.config/waybar/wallpaper.conf")
        assignments = []
        if os.path.exists(state_file):
            try:
                with open(state_file, 'r') as f:
                    for line in f:
                        if line.startswith("assignment="):
                            payload = line.replace("assignment=", "").strip()
                            m = payload.split("|")[0]
                            f_path = payload.split("|")[1] if len(payload.split("|")) > 1 else ""
                            if m != monitor and m != "ALL":
                                assignments.append(f"{m}|{f_path}")
            except:
                pass
                
        # Insert new assignment
        if monitor == "ALL":
            assignments = [f"ALL|{wall_path}"]
        else:
            # check if ALL was present, if so, map other monitors to ALL's file
            has_all = any(x.startswith("ALL|") for x in assignments)
            if has_all:
                all_val = [x.split("|")[1] for x in assignments if x.startswith("ALL|")][0]
                assignments = []
                # Fetch monitors list
                mon_list = []
                try:
                    output = subprocess.check_output(["hyprctl", "monitors", "-j"], stderr=subprocess.DEVNULL)
                    mon_data = json.loads(output)
                    mon_list = [x.get("name") for x in mon_data if x.get("name")]
                except:
                    mon_list = ["eDP-1", "HDMI-A-1"]
                for mon in mon_list:
                    if mon == monitor:
                        assignments.append(f"{mon}|{wall_path}")
                    else:
                        assignments.append(f"{mon}|{all_val}")
            else:
                # remove existing entry for this monitor if present
                assignments = [x for x in assignments if not x.startswith(f"{monitor}|")]
                assignments.append(f"{monitor}|{wall_path}")
                
        # Write back to state file
        try:
            with open(state_file, 'w') as f:
                for entry in assignments:
                    f.write(f"assignment={entry}\n")
        except Exception as e:
            print(f"Error writing state file: {e}")
            
        # 2. Trigger Wallpaper and Theme synchronization
        sync_script = os.path.expanduser("~/.config/waybar/scripts/aiko-wall-sync.py")
        wall_script = os.path.expanduser("~/.config/waybar/scripts/wallpaper.sh")
        
        # We start sync asynchronously to let the UI react quickly
        def apply_task():
            if os.path.exists(sync_script):
                subprocess.run(["python3", sync_script, wall_path])
            elif os.path.exists(wall_script):
                subprocess.run(["bash", wall_script, "apply"])
                
        threading.Thread(target=apply_task).start()
        
        # Show a desktop notification
        try:
            subprocess.run(["notify-send", "Aiko Wallpaper Engine", f"Wallpaper applied to {monitor}!\nSyncing accent colors..."])
        except:
            pass
            
        # Close the widget
        self.close()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.keyval_from_name("Escape"):
            self.close()
            return True
        return False

if __name__ == "__main__":
    AikoWallpaper()
