#!/usr/bin/env bash
# Clipboard history picker — SUPER+V.
#
# Shows text entries as text and image entries as actual thumbnails.
#
# Three rofi/shell details do the work:
#
#   \0icon\x1f<path>   per-row icon metadata. rofi strips it from the returned
#                      value, so it never pollutes the selection.
#
#   emit in a pipe     the NUL in that delimiter CANNOT survive a bash
#                      variable — command substitution silently drops NUL
#                      bytes, and the row then displays the literal text
#                      "…icon/home/…". Rows must be printf'd directly into
#                      rofi's stdin, never collected into an array first.
#
#   -format i          returns the row INDEX. cliphist's list output is
#                      "<id>\t<preview>"; displaying that raw would put a
#                      numeric id in front of every row. Selecting by index
#                      keeps the ids hidden and looked up afterwards.
#
# Keys:  Enter = copy   ·   Alt+x = remove entry   ·   Alt+c = wipe all
#
# Shift+Delete would be the obvious removal key, but rofi already binds it to
# kb-delete-entry; a clashing -kb-custom-1 makes rofi refuse to open and print
# a binding error instead of the menu.

THEME="$HOME/.config/rofi/clipboard.rasi"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
mkdir -p "$CACHE"

# Drop thumbnails whose entry has long since left the history.
find "$CACHE" -type f -mtime +7 -delete 2>/dev/null

mapfile -t entries < <(cliphist list 2>/dev/null)
if [ "${#entries[@]}" -eq 0 ]; then
    notify-send "Clipboard" "History is empty."
    exit 0
fi

# Build parallel arrays: ids for lookup, labels for display, thumbs for icons.
ids=()
labels=()
thumbs=()

for line in "${entries[@]}"; do
    id="${line%%$'\t'*}"
    preview="${line#*$'\t'}"
    ids+=("$id")

    case "$preview" in
        *"binary data"*)
            thumb="$CACHE/$id.png"
            if [ ! -s "$thumb" ]; then
                # Decode once, then downscale — full-size images make rofi crawl.
                if cliphist decode "$id" > "$thumb.raw" 2>/dev/null; then
                    magick "$thumb.raw" -thumbnail 96x96 "$thumb" 2>/dev/null \
                        || mv "$thumb.raw" "$thumb"
                fi
                rm -f "$thumb.raw"
            fi
            # Trim cliphist's "[[ binary data 182 KiB png 800x480 ]]" wrapper.
            labels+=("$(printf '%s' "$preview" | sed -E 's/^\[\[ binary data //; s/ \]\]$//')")
            thumbs+=("$thumb")
            ;;
        *)
            labels+=("$preview")
            thumbs+=("")
            ;;
    esac
done

emit_rows() {
    local i
    for i in "${!labels[@]}"; do
        if [ -n "${thumbs[$i]}" ] && [ -s "${thumbs[$i]}" ]; then
            printf '%s\0icon\x1f%s\n' "${labels[$i]}" "${thumbs[$i]}"
        else
            printf '%s\n' "${labels[$i]}"
        fi
    done
}

chosen=$(emit_rows | rofi -dmenu \
    -theme "$THEME" \
    -p "Clipboard" \
    -format i \
    -show-icons \
    -no-custom \
    -kb-custom-1 "Alt+x" \
    -kb-custom-2 "Alt+c")
status=$?

case "$status" in
    0)  # copy
        [ -n "$chosen" ] && cliphist decode "${ids[$chosen]}" | wl-copy
        ;;
    10) # Alt+x — remove just this entry
        if [ -n "$chosen" ]; then
            printf '%s\n' "${entries[$chosen]}" | cliphist delete
            rm -f "$CACHE/${ids[$chosen]}.png"
            notify-send "Clipboard" "Entry removed."
        fi
        ;;
    11) # Alt+c — wipe the whole history
        cliphist wipe
        rm -f "$CACHE"/*.png
        notify-send "Clipboard" "History cleared."
        ;;
esac
