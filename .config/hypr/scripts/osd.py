#!/usr/bin/env python3
"""On-screen display for volume and brightness keys, Windows-style.

A small pill at the bottom centre of the screen, on the overlay layer so it
shows over fullscreen windows too, and click-through so it never steals input.

Runs as a daemon (started at login). osd.sh changes the level, then sends
SIGUSR1 (volume) or SIGUSR2 (brightness); the daemon reads the current value
itself, shows the pill, and hides it again after a short delay.
"""
import os
import signal
import subprocess
import sys

import cairo
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("GLibUnix", "2.0")
from gi.repository import Gdk, GLib, GLibUnix, Gtk, GtkLayerShell  # noqa: E402

PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "hypr-osd.pid")
TIMEOUT_MS = 1500
BOTTOM = 80  # clears the quote bar along the bottom edge

CSS = b"""
window { background: transparent; }
.osd {
    background: rgba(24, 22, 33, 0.82);
    border: 1px solid rgba(203, 166, 247, 0.22);
    border-radius: 18px;
    padding: 9px 16px;
}
.osd label {
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", monospace;
    font-weight: 500;
    color: #c8ccd6;
}
.osd .icon  { font-size: 16px; }
.osd .value { font-size: 12px; }
progressbar trough {
    min-height: 4px;
    border-radius: 2px;
    background: rgba(120, 106, 156, 0.35);
    border: none;
}
progressbar progress {
    min-height: 4px;
    border-radius: 2px;
    background: #cba6f7;
    border: none;
}
.muted progressbar progress { background: #7a7f8c; }
.muted label { color: #7a7f8c; }
"""


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def read_volume():
    # "Volume: 0.45" or "Volume: 0.45 [MUTED]"
    out = run("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@").split()
    try:
        level = float(out[1])
    except (IndexError, ValueError):
        return None
    muted = "[MUTED]" in out
    if muted or level == 0:
        icon = "󰝟"
    else:
        icon = ["󰕿", "󰖀", "󰕾"][min(2, int(level * 3))]
    return icon, level, muted


def read_brightness():
    out = run("busctl", "--user", "get-property", "rs.wl-gammarelay", "/",
              "rs.wl.gammarelay", "Brightness").split()
    try:
        level = float(out[1])
    except (IndexError, ValueError):
        return None
    icon = ["󰃞", "󰃟", "󰃠"][min(2, int(level * 3))]
    return icon, level, False


class Osd(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.hide_timer = None

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "osd")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, BOTTOM)
        GtkLayerShell.set_exclusive_zone(self, -1)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        self.box.get_style_context().add_class("osd")
        self.box.set_size_request(240, -1)

        self.icon = Gtk.Label()
        self.icon.get_style_context().add_class("icon")
        self.icon.set_width_chars(2)

        self.bar = Gtk.ProgressBar()
        self.bar.set_hexpand(True)
        self.bar.set_valign(Gtk.Align.CENTER)

        self.value = Gtk.Label()
        self.value.get_style_context().add_class("value")
        self.value.set_width_chars(3)
        self.value.set_xalign(1)

        self.box.pack_start(self.icon, False, False, 0)
        self.box.pack_start(self.bar, True, True, 0)
        self.box.pack_start(self.value, False, False, 0)
        self.add(self.box)

        # Click-through: an empty input region lets clicks reach the window below.
        self.connect("realize", lambda w: w.get_window().input_shape_combine_region(
            cairo.Region(), 0, 0))
        self.box.show_all()

    def show_level(self, reader):
        state = reader()
        if state is None:
            return GLib.SOURCE_CONTINUE
        icon, level, muted = state
        self.icon.set_text(icon)
        self.bar.set_fraction(max(0.0, min(1.0, level)))
        self.value.set_text(str(round(level * 100)))
        ctx = self.box.get_style_context()
        (ctx.add_class if muted else ctx.remove_class)("muted")

        self.show()
        if self.hide_timer is not None:
            GLib.source_remove(self.hide_timer)
        self.hide_timer = GLib.timeout_add(TIMEOUT_MS, self.on_timeout)
        return GLib.SOURCE_CONTINUE

    def on_timeout(self):
        self.hide_timer = None
        self.hide()
        return False


def main():
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    osd = Osd()
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, osd.show_level, read_volume)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR2, osd.show_level, read_brightness)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda: Gtk.main_quit() or False)
    # Started on demand by osd.sh: show what triggered the launch right away.
    if len(sys.argv) > 1:
        osd.show_level(read_volume if sys.argv[1] == "volume" else read_brightness)
    try:
        Gtk.main()
    finally:
        try:
            os.remove(PIDFILE)
        except OSError:
            pass


if __name__ == "__main__":
    main()
