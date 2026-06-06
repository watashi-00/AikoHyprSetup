import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib

# Force dark theme variant
settings = Gtk.Settings.get_default()
if settings:
    settings.set_property("gtk-application-prefer-dark-theme", True)

import os
import json
import sys

class AikoList(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Tasks")
        
        # Identity for Hyprland rules
        self.set_name("aiko-list-window")
        self.set_role("aiko-list")
        
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(350, 450)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Data file setup
        self.data_file = os.path.expanduser("~/.cache/aiko-tasks.json")
        os.makedirs(os.path.dirname(self.data_file), exist_ok=True)
        self.tasks = self.load_tasks()

        # CSS setup
        self.load_css()

        # Main Box (Transparent)
        self.main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(self.main_vbox)

        # Styled Container
        self.styled_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.styled_container.set_name("main-container")
        self.main_vbox.pack_start(self.styled_container, True, True, 0)

        # Header Section
        self.header_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.header_hbox.set_name("list-header")
        self.header_hbox.set_margin_top(20)
        self.header_hbox.set_margin_bottom(10)
        self.header_hbox.set_margin_start(20)
        self.header_hbox.set_margin_end(20)
        self.styled_container.pack_start(self.header_hbox, False, False, 0)

        title_label = Gtk.Label(label="Tasks")
        title_label.set_name("list-title")
        title_label.set_halign(Gtk.Align.START)
        self.header_hbox.pack_start(title_label, True, True, 0)

        self.add_btn = Gtk.Button(label="+")
        self.add_btn.set_name("list-add-btn")
        self.add_btn.connect("clicked", self.on_add_clicked)
        self.header_hbox.pack_end(self.add_btn, False, False, 0)

        # List Section
        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scrolled.set_shadow_type(Gtk.ShadowType.NONE)
        self.styled_container.pack_start(self.scrolled, True, True, 0)

        self.list_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        self.list_vbox.set_name("list-container")
        self.list_vbox.set_margin_start(20)
        self.list_vbox.set_margin_end(20)
        self.list_vbox.set_margin_bottom(20)
        self.scrolled.add(self.list_vbox)

        self.refresh_list()

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)
        
        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def load_tasks(self):
        if os.path.exists(self.data_file):
            try:
                with open(self.data_file, "r") as f:
                    return json.load(f)
            except:
                return []
        return []

    def save_tasks(self):
        try:
            with open(self.data_file, "w") as f:
                json.dump(self.tasks, f)
        except Exception as e:
            print(f"Error saving tasks: {e}")

    def load_css(self):
        css_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "theme.css")
        if os.path.exists(css_path):
            provider = Gtk.CssProvider()
            provider.load_from_path(css_path)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def refresh_list(self):
        # Clear current list
        for child in self.list_vbox.get_children():
            self.list_vbox.remove(child)

        for i, task in enumerate(self.tasks):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            row.set_name("task-row")

            check = Gtk.CheckButton()
            check.set_name("task-check")
            check.set_active(task["done"])
            check.connect("toggled", self.on_task_toggled, i)
            row.pack_start(check, False, False, 0)

            label = Gtk.Label(label=task["text"])
            label.set_name("task-label")
            if task["done"]:
                label.get_style_context().add_class("done")
            label.set_halign(Gtk.Align.START)
            label.set_line_wrap(True)
            label.set_max_width_chars(30)
            label.set_xalign(0)
            row.pack_start(label, True, True, 0)

            delete_btn = Gtk.Button(label="×")
            delete_btn.set_name("task-delete-btn")
            delete_btn.connect("clicked", self.on_delete_clicked, i)
            row.pack_end(delete_btn, False, False, 0)

            self.list_vbox.pack_start(row, False, False, 0)
        
        self.list_vbox.show_all()

    def on_task_toggled(self, check, index):
        self.tasks[index]["done"] = check.get_active()
        self.save_tasks()
        self.refresh_list()

    def on_delete_clicked(self, btn, index):
        del self.tasks[index]
        self.save_tasks()
        self.refresh_list()

    def on_add_clicked(self, btn):
        dialog = Gtk.Dialog(title="New Task", parent=self, flags=0)
        dialog.set_name("task-dialog")
        dialog.set_decorated(False)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        
        # Style the dialog
        dialog.get_content_area().set_spacing(10)
        dialog.get_content_area().set_margin_top(15)
        dialog.get_content_area().set_margin_bottom(15)
        dialog.get_content_area().set_margin_start(15)
        dialog.get_content_area().set_margin_end(15)

        entry = Gtk.Entry()
        entry.set_placeholder_text("Task description...")
        entry.set_activates_default(True)
        dialog.get_content_area().pack_start(entry, True, True, 0)
        
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            text = entry.get_text().strip()
            if text:
                self.tasks.append({"text": text, "done": False})
                self.save_tasks()
                self.refresh_list()
        
        dialog.destroy()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()
        if (event.state & Gdk.ModifierType.CONTROL_MASK):
            if event.keyval == Gdk.KEY_q or event.keyval == Gdk.KEY_w:
                self.destroy()

if __name__ == "__main__":
    AikoList()
    Gtk.main()
