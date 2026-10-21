#!/usr/bin/env bash
# Change volume or brightness, then flash the on-screen display (osd.py).
#   osd.sh volume up|down|mute
#   osd.sh brightness up|down
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-osd.pid"
DIR="$(dirname "$(readlink -f "$0")")"

case "$1 $2" in
    "volume up")       wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
    "volume down")     wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    "volume mute")     wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    "brightness up")   "$HOME/.config/waybar/scripts/brightness.sh" up ;;
    "brightness down") "$HOME/.config/waybar/scripts/brightness.sh" down ;;
    *) echo "usage: osd.sh volume up|down|mute | brightness up|down" >&2; exit 1 ;;
esac

sig=USR1; [ "$1" = brightness ] && sig=USR2
pid=$(cat "$PIDFILE" 2>/dev/null)
# Only signal the pid if it really is the OSD (guards against a stale pidfile).
if [ -n "$pid" ] && grep -q osd.py "/proc/$pid/cmdline" 2>/dev/null; then
    kill -"$sig" "$pid"
else
    setsid -f "$DIR/osd.py" "$1" >/dev/null 2>&1 </dev/null
fi
