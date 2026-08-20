#!/usr/bin/env bash
# Terminal file manager, with fallbacks.
#
# This lives in a script rather than inline in hyprland.lua on purpose.
# hl.dsp.exec_cmd() already runs its argument through a shell, so an inline
# `sh -c '... $f ...'` gets its variables expanded by the OUTER shell first —
# $f arrives empty, and the command becomes `kitty -e` with no program, which
# exits instantly and looks like the keybind doing nothing.

for fm in yazi ranger lf nnn vifm; do
    if command -v "$fm" >/dev/null 2>&1; then
        exec kitty -e "$fm" "$@"
    fi
done

# Nothing terminal-based available — fall back to the graphical manager.
exec nautilus "$@"
