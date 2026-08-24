#!/usr/bin/env bash
# Pick one splash quote for the whole session.
#
# Replaces Hyprland's built-in splash, whose list is compiled into the binary
# and cannot be extended without rebuilding from source. Reading from a plain
# text file keeps the list editable and update-proof.
#
# WHY THE CACHE: waybar evaluates a custom module once per output, so a plain
# `shuf` gives each monitor a different quote. The chosen line is stored in
# XDG_RUNTIME_DIR so every bar on every screen reads the same one. That
# directory is wiped on logout, so a new quote is picked each session.
QUOTES="$HOME/.config/hypr/quotes.txt"
STATE="${XDG_RUNTIME_DIR:-/tmp}/splash-quote"

[ -r "$QUOTES" ] || exit 0

if [ ! -s "$STATE" ]; then
    line=$(grep -vE '^\s*(#|$)' "$QUOTES" | shuf -n 1)
    [ -z "$line" ] && exit 0

    # Escape the characters Pango treats as markup — waybar renders module text
    # as markup, and a stray & or < blanks the module entirely.
    printf '%s\n' "$line" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' > "$STATE.$$"

    # Hard-linking fails if the target already exists, so whichever bar gets
    # here first wins and the rest reuse its pick. A plain mv would let the
    # second monitor overwrite the first and they would disagree again.
    ln "$STATE.$$" "$STATE" 2>/dev/null
    rm -f "$STATE.$$"
fi

cat "$STATE" 2>/dev/null
