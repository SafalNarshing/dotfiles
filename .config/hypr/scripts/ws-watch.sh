#!/usr/bin/env python3
"""Nudge waybar the moment the workspace changes.

The workspace dots are five custom modules, which waybar can only refresh on a
timer or on a signal. On a timer the pill visibly lags behind the actual
switch. This listens to Hyprland's event socket and sends SIGRTMIN+1, which
waybar treats as "re-run every module configured with signal 1" — so all five
dots update together, immediately.

Written in python rather than shell because socat is not installed and this
needs a persistent reader on a unix socket.
"""

import os
import signal
import socket
import subprocess
import sys

# Events that can change which workspace is focused or occupied.
WATCH = (
    "workspace>>", "workspacev2>>", "focusedmon>>", "focusedmonv2>>",
    "createworkspace>>", "createworkspacev2>>",
    "destroyworkspace>>", "destroyworkspacev2>>",
    "openwindow>>", "closewindow>>", "movewindow>>", "movewindowv2>>",
)

# waybar maps "signal": N to SIGRTMIN+N.
SIGNUM = signal.SIGRTMIN + 1


def socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        sys.exit("HYPRLAND_INSTANCE_SIGNATURE not set — not inside a Hyprland session")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
    return os.path.join(runtime, "hypr", sig, ".socket2.sock")


def main():
    path = socket_path()
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)

    buf = b""
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            text = line.decode("utf-8", "replace")
            if any(text.startswith(e) for e in WATCH):
                # pkill rather than a tracked pid: there are two waybar
                # instances (main bar + quote bar) and either may restart.
                subprocess.run(["pkill", "-%d" % SIGNUM, "-x", "waybar"],
                               check=False)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, ConnectionError, FileNotFoundError):
        sys.exit(0)
