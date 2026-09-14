#!/usr/bin/env bash
# Snip a region, run OCR on it, put the TEXT on the clipboard — SUPER+SHIFT+T.
#
# Companion to SUPER+SHIFT+S, which copies the image itself. This one copies
# what the image says, so you can paste it into an editor.
#
# Pipeline: slurp picks the region -> grim captures it -> the image is upscaled
# and thresholded -> tesseract reads it -> wl-copy takes the text.
#
# The preprocessing matters more than it looks. Tesseract was trained on ~300
# DPI scans; a screen region is closer to 96 DPI, and feeding it raw produces
# noticeably worse output. Scaling 3x and flattening to high-contrast greyscale
# typically turns a garbled result into a clean one.

set -o pipefail

# English and Nepali together. Tesseract accepts several languages in one pass
# and these two use different scripts (Latin vs Devanagari), so it separates
# them cleanly — no detection step needed. Tesseract cannot auto-detect a
# LANGUAGE anyway; it can only detect a script, and only with the osd pack.
#
# Falls back to whichever packs are actually present, so a missing Nepali pack
# degrades to English rather than making every capture fail.
pick_langs() {
    local have=()
    for l in eng nep; do
        tesseract --list-langs 2>/dev/null | grep -qx "$l" && have+=("$l")
    done
    [ ${#have[@]} -eq 0 ] && { echo eng; return; }
    local IFS=+; echo "${have[*]}"
}
LANG_DATA="${OCR_LANG:-$(pick_langs)}"
TMP="$(mktemp -t ocr-XXXXXX.png)"
trap 'rm -f "$TMP" "$TMP.txt"' EXIT

need() {
    command -v "$1" >/dev/null 2>&1 && return 0
    notify-send "OCR unavailable" "$1 is not installed.\n\nsudo pacman -S tesseract tesseract-data-eng tesseract-data-nep"
    exit 1
}
need slurp
need grim
need tesseract

# slurp exits non-zero when the selection is cancelled with Escape — that is a
# normal way to back out, not an error worth reporting.
region=$(slurp 2>/dev/null) || exit 0
[ -z "$region" ] && exit 0

grim -g "$region" "$TMP" || { notify-send "OCR failed" "Could not capture the region."; exit 1; }

# Upscale and threshold before recognition. -sharpen recovers edges softened by
# the upscale; -normalize stretches contrast so anti-aliased text separates
# cleanly from its background.
if command -v magick >/dev/null 2>&1; then
    magick "$TMP" -colorspace Gray -resize 300% -sharpen 0x1 -normalize "$TMP" 2>/dev/null
fi

text=$(tesseract "$TMP" - -l "$LANG_DATA" --psm 6 2>/dev/null)

# Trim trailing blank lines tesseract habitually appends.
text=$(printf '%s' "$text" | sed -e 's/[[:space:]]*$//' -e '/./,$!d' | awk 'NF {p=1} p')

if [ -z "${text//[[:space:]]/}" ]; then
    notify-send "OCR" "No text found in that region."
    exit 0
fi

printf '%s' "$text" | wl-copy

# Preview the first line so it is obvious the capture worked without pasting.
preview=$(printf '%s' "$text" | head -c 120 | tr '\n' ' ')
chars=$(printf '%s' "$text" | wc -c)
notify-send "OCR — ${chars} chars copied" "$preview"
