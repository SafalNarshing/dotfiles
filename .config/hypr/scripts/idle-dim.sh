#!/usr/bin/env bash
# Idle dimming for an OLED panel with no backlight.
#
# brightnessctl and every other backlight approach is a no-op on this display,
# so dimming is done by lowering the wl-gammarelay-rs gamma level. The level in
# use is saved first, and restored on resume — otherwise resuming would snap the
# screen to a hardcoded value and lose whatever the user had set.
#
# Naming gotcha, do not "fix": the D-Bus service uses a hyphen, the interface
# uses only periods. They are deliberately different.
SVC="rs.wl-gammarelay"
IFACE="rs.wl.gammarelay"
STATE="${XDG_RUNTIME_DIR:-/tmp}/idle-dim.level"
DIM_TO=0.15

get() { busctl --user get-property "$SVC" / "$IFACE" Brightness 2>/dev/null | awk '{print $2}'; }
set_to() { busctl --user set-property "$SVC" / "$IFACE" Brightness d "$1" >/dev/null 2>&1; }

case "$1" in
    dim)
        cur=$(get)
        [ -z "$cur" ] && exit 0
        # Never save the dim level itself — a second dim before any resume
        # would otherwise make the dim permanent.
        [ -f "$STATE" ] || printf '%s' "$cur" > "$STATE"
        # Only dim if we are currently brighter than the target.
        awk -v c="$cur" -v d="$DIM_TO" 'BEGIN { exit !(c > d) }' && set_to "$DIM_TO"
        ;;
    restore)
        if [ -f "$STATE" ]; then
            prev=$(cat "$STATE")
            rm -f "$STATE"
            [ -n "$prev" ] && set_to "$prev"
        else
            set_to 1.0
        fi
        ;;
esac
