#!/usr/bin/env python3
"""Floating brightness slider, opened by clicking the waybar brightness icon.

A gtk-layer-shell surface that drops down just below the bar, centred under
the cursor. Clicking the icon again closes it, as do Escape, clicking
somewhere else, or moving the pointer away. All brightness changes go through
brightness.sh so the clamping and state file stay in one place.
"""
import json
import os
import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

SCRIPT = os.path.expanduser("~/.config/waybar/scripts/brightness.sh")
PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-brightness-popup.pid")
WIDTH = 240
GAP = 6  # space between the bar and the popup

CSS = b"""
window {
    background: transparent;
}
.popup {
    background: rgba(40, 36, 54, 0.85);
    border: 1px solid rgba(203, 166, 247, 0.22);
    border-radius: 11px;
    padding: 10px 14px;
}
.popup label {
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
    font-size: 12px;
    font-weight: 500;
    color: #c8ccd6;
}
.popup .icon { font-size: 14px; }
scale trough {
    min-height: 6px;
    border-radius: 3px;
    background: rgba(78, 71, 100, 0.6);
    border: none;
}
scale highlight {
    border-radius: 3px;
    background: #cba6f7;
}
scale slider {
    min-width: 14px;
    min-height: 14px;
    margin: -5px;
    border-radius: 7px;
    background: #dfe3ec;
    border: none;
    box-shadow: none;
}
"""


def toggle_existing():
    """If a popup is already open, close it and report True."""
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        # Guard against a stale pidfile whose pid now belongs to something else.
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            if b"brightness-popup" not in f.read():
                return False
        os.kill(pid, signal.SIGTERM)
        return True
    except (OSError, ValueError):
        return False


def current_level():
    out = subprocess.run(
        ["busctl", "--user", "get-property", "rs.wl-gammarelay", "/",
         "rs.wl.gammarelay", "Brightness"],
        capture_output=True, text=True,
    ).stdout.split()
    try:
        return round(float(out[1]) * 100)
    except (IndexError, ValueError):
        return 100


def left_margin():
    """Horizontal offset that centres the popup under the cursor."""
    try:
        cx = int(subprocess.run(["hyprctl", "cursorpos"], capture_output=True,
                                text=True).stdout.split(",")[0])
        mons = json.loads(subprocess.run(["hyprctl", "-j", "monitors"],
                                         capture_output=True, text=True).stdout)
        mon = next(m for m in mons if m.get("focused")) if mons else None
        mx = mon["x"]
        mw = mon["width"] / mon["scale"]
        if mon.get("transform", 0) % 2:
            mw = mon["height"] / mon["scale"]
    except Exception:
        return None
    return int(max(8, min(cx - mx - WIDTH / 2, mw - WIDTH - 8)))


class Popup(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.pending = None
        self.close_timer = None

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "waybar-brightness")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, GAP)
        margin = left_margin()
        if margin is not None:
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, margin)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.get_style_context().add_class("popup")
        box.set_size_request(WIDTH, -1)

        icon = Gtk.Label(label="󰃠")
        icon.get_style_context().add_class("icon")

        level = current_level()
        adj = Gtk.Adjustment(value=level, lower=10, upper=100,
                             step_increment=5, page_increment=5)
        self.scale = Gtk.Scale(orientation=Gtk.Orientation.HORIZONTAL, adjustment=adj)
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.connect("value-changed", self.on_changed)

        self.label = Gtk.Label(label=f"{level}%")
        self.label.set_width_chars(4)
        self.label.set_xalign(1)

        box.pack_start(icon, False, False, 0)
        box.pack_start(self.scale, True, True, 0)
        box.pack_start(self.label, False, False, 0)
        self.add(box)

        self.connect("key-press-event", self.on_key)
        self.connect("focus-out-event", lambda *_: self.quit())
        self.connect("enter-notify-event", self.on_enter)
        self.connect("leave-notify-event", self.on_leave)
        # Never hovered (e.g. opened by accident): don't linger forever.
        self.schedule_close(4000)

    def on_changed(self, scale):
        value = int(round(scale.get_value()))
        self.label.set_text(f"{value}%")
        # Dragging fires many events; apply at most one change per ~30 ms.
        if self.pending is None:
            self.pending = GLib.timeout_add(30, self.apply)

    def apply(self):
        self.pending = None
        value = int(round(self.scale.get_value()))
        subprocess.Popen([SCRIPT, "set", f"{value / 100:.2f}"])
        return False

    def on_key(self, _w, event):
        if event.keyval == Gdk.KEY_Escape:
            self.quit()

    def on_enter(self, _w, event):
        if event.detail != Gdk.NotifyType.INFERIOR:
            self.cancel_close()

    def on_leave(self, _w, event):
        if event.detail != Gdk.NotifyType.INFERIOR:
            self.schedule_close(800)

    def schedule_close(self, ms):
        self.cancel_close()
        self.close_timer = GLib.timeout_add(ms, self.quit)

    def cancel_close(self):
        if self.close_timer is not None:
            GLib.source_remove(self.close_timer)
            self.close_timer = None

    def quit(self, *_):
        if self.pending is not None:
            GLib.source_remove(self.pending)
            self.apply()
        Gtk.main_quit()
        return False


def main():
    if toggle_existing():
        return
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    try:
        win = Popup()
        try:
            gi.require_version("GLibUnix", "2.0")
            from gi.repository import GLibUnix
            GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, win.quit)
        except (ImportError, ValueError):
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, win.quit)
        win.show_all()
        Gtk.main()
    finally:
        try:
            os.remove(PIDFILE)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
