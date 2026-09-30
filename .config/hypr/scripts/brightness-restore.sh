#!/usr/bin/env bash
# Re-apply the last brightness at login.
#
# wl-gammarelay-rs is launched from the same autostart block, so it may not be
# on D-Bus yet when this runs. Poll briefly for the service rather than
# sleeping a fixed time. The saved value is clamped so a corrupt or hand-edited
# state file can never black the panel out.
SVC="rs.wl-gammarelay"
IFACE="rs.wl.gammarelay"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/brightness"

[ -r "$STATE_FILE" ] || exit 0
level=$(awk 'NR==1 { v=$1+0; if (v<0.1) v=0.1; if (v>1) v=1; printf "%.2f", v }' "$STATE_FILE")

for _ in $(seq 50); do            # up to ~5s
    busctl --user get-property "$SVC" / "$IFACE" Brightness >/dev/null 2>&1 && break
    sleep 0.1
done
busctl --user set-property "$SVC" / "$IFACE" Brightness d "$level" >/dev/null 2>&1
