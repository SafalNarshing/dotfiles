#!/usr/bin/env bash
# Power menu via rofi, replacing waybar's GTK popup menu.
#
# Each row shows its glyph alongside the action name.
#
# Two rofi details make that work:
#   -sep '|'    keeps the separator independent of the entry text.
#   -format i   returns the INDEX of the chosen entry rather than its text.
#               Matching on the glyph would otherwise break the moment a
#               label or icon changes.

THEME="$HOME/.config/rofi/powermenu.rasi"

# One line per action: glyph, gap, label. Rofi's listview elements are
# single-line — a "\n" inside an entry does not wrap, it overflows the line
# box and gets clipped, which is why the label cannot sit under the icon.
entry() { printf '%s   %s' "$1" "$2"; }

options="$(entry '󰌾' 'Lock')|$(entry '󰒲' 'Suspend')|$(entry '󰍃' 'Log out')|$(entry '󰜉' 'Restart')|$(entry '󰐥' 'Shut down')"

chosen=$(printf '%s' "$options" \
    | rofi -dmenu \
           -theme "$THEME" \
           -p "Session" \
           -sep '|' \
           -format i \
           -markup-rows \
           -no-custom \
           -selected-row 0)

# Yes/no confirmation, reusing the same card styling.
confirm() {
    local answer
    answer=$(printf '%s|%s' \
                "$(entry '󰄬' 'Yes')" \
                "$(entry '󰅖' 'No')" \
             | rofi -dmenu -theme "$THEME" -p "$1?" \
                    -sep '|' -format i -markup-rows -no-custom -selected-row 1)
    [ "$answer" = "0" ]
}

case "$chosen" in
    0)  # Lock — hyprlock has no config yet; refuse rather than risk a lock-out.
        if [ -f "$HOME/.config/hypr/hyprlock.conf" ]; then
            hyprlock
        else
            notify-send "Lock unavailable" "No hyprlock.conf yet — configure it first."
        fi
        ;;
    1)  systemctl suspend ;;
    2)  confirm "Log out"   && hyprctl dispatch 'hl.dsp.exit()' ;;
    3)  confirm "Restart"   && systemctl reboot ;;
    4)  confirm "Shut down" && systemctl poweroff ;;
esac
