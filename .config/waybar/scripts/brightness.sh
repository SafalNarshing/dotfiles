#!/usr/bin/env bash
# Brightness via wl-gammarelay-rs (gamma ramp, NOT backlight — this is an OLED panel
# with no physical backlight; see the notes in the Hyprland config).
#
# Naming gotcha, do not "fix" these: the D-Bus *service* uses a hyphen, the
# *interface* uses only periods. They are deliberately different.
SVC="rs.wl-gammarelay"
IFACE="rs.wl.gammarelay"
STEP=0.05

get_raw() {
    busctl --user get-property "$SVC" / "$IFACE" Brightness 2>/dev/null | awk '{print $2}'
}

set_abs() {
    busctl --user set-property "$SVC" / "$IFACE" Brightness d "$1" >/dev/null 2>&1
}

case "$1" in
    up|down)
        cur=$(get_raw)
        [ -z "$cur" ] && exit 0
        # UpdateBrightness does not clamp and will happily run past 1.0 or below
        # 0.0, blacking out the screen. Compute and clamp ourselves instead.
        new=$(awk -v c="$cur" -v s="$STEP" -v d="$1" \
            'BEGIN { v = (d == "up") ? c + s : c - s;
                     if (v > 1.0) v = 1.0;
                     if (v < 0.1) v = 0.1;      # floor: never fully black
                     printf "%.2f", v }')
        set_abs "$new"
        ;;
    reset)
        set_abs 1.0
        ;;
    *)
        # Default: emit current level for waybar
        cur=$(get_raw)
        if [ -z "$cur" ]; then
            echo '{"text":"--","tooltip":"wl-gammarelay-rs not running","class":"off"}'
            exit 0
        fi
        pct=$(awk -v c="$cur" 'BEGIN { printf "%d", c * 100 }')
        echo "{\"text\":\"${pct}%\",\"percentage\":${pct},\"tooltip\":\"Brightness ${pct}% (gamma)\\nScroll to adjust\"}"
        ;;
esac
