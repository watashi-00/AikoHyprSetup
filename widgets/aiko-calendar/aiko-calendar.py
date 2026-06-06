import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib

# Force dark theme variant
settings = Gtk.Settings.get_default()
if settings:
    settings.set_property("gtk-application-prefer-dark-theme", True)

import os
import sys
import datetime
import calendar

class AikoCalendar(Gtk.Window):
    def __init__(self):
        super().__init__(title="Aiko Calendar")
        self.set_name("aiko-calendar-window")
        self.set_role("aiko-calendar")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(320, 380)

        self.today = datetime.date.today()
        self.current_year = self.today.year
        self.current_month = self.today.month

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

        # Header Box (Prev, Title, Next)
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        header_box.set_name("header-box")
        content_vbox.pack_start(header_box, False, False, 0)

        prev_btn = Gtk.Button(label="◀")
        prev_btn.set_name("nav-btn")
        prev_btn.connect("clicked", self.on_prev_month)
        header_box.pack_start(prev_btn, False, False, 0)

        self.title_label = Gtk.Label()
        self.title_label.set_name("month-title")
        header_box.pack_start(self.title_label, True, True, 0)

        next_btn = Gtk.Button(label="▶")
        next_btn.set_name("nav-btn")
        next_btn.connect("clicked", self.on_next_month)
        header_box.pack_start(next_btn, False, False, 0)

        # Weekdays Header Box
        weekdays_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        weekdays_box.set_name("weekdays-box")
        content_vbox.pack_start(weekdays_box, False, False, 0)

        days = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
        for d in days:
            lbl = Gtk.Label(label=d)
            lbl.set_name("weekday-label")
            weekdays_box.pack_start(lbl, True, True, 0)

        # Days Grid
        self.days_grid = Gtk.Grid()
        self.days_grid.set_column_homogeneous(True)
        self.days_grid.set_row_homogeneous(True)
        self.days_grid.set_row_spacing(6)
        self.days_grid.set_column_spacing(6)
        content_vbox.pack_start(self.days_grid, True, True, 0)

        self.populate_days()

        # Event connections
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Transparent background support
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.show_all()

    def populate_days(self):
        # Clear old grid widgets
        for child in self.days_grid.get_children():
            self.days_grid.remove(child)

        # Month info
        self.title_label.set_text(f"{calendar.month_name[self.current_month]} {self.current_year}")

        month_calendar = calendar.monthcalendar(self.current_year, self.current_month)

        for row, week in enumerate(month_calendar):
            for col, day in enumerate(week):
                if day == 0:
                    btn = Gtk.Button(label="")
                    btn.set_name("empty-day")
                    btn.set_sensitive(False)
                else:
                    btn = Gtk.Button(label=str(day))
                    btn.set_name("day-btn")
                    
                    if (self.current_year == self.today.year and 
                        self.current_month == self.today.month and 
                        day == self.today.day):
                        btn.set_name("today-btn")
                        
                self.days_grid.attach(btn, col, row, 1, 1)

        self.days_grid.show_all()

    def on_prev_month(self, widget):
        self.current_month -= 1
        if self.current_month == 0:
            self.current_month = 12
            self.current_year -= 1
        self.populate_days()

    def on_next_month(self, widget):
        self.current_month += 1
        if self.current_month == 13:
            self.current_month = 1
            self.current_year += 1
        self.populate_days()

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
        AikoCalendar()
        Gtk.main()
    except Exception as e:
        print(f"Failed to start AikoCalendar: {e}")
        sys.exit(1)
