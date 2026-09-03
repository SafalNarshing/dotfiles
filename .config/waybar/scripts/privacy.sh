#!/usr/bin/env bash
# Privacy indicator: is the microphone or the camera actually in use right now?
#
# Usage: privacy.sh mic   -> JSON, empty text when idle
#        privacy.sh cam   -> JSON, empty text when idle
#
# Empty text is deliberate: waybar hides a custom module whose text is empty,
# so each indicator disappears completely when nothing is using that device
# rather than sitting there greyed out.
#
# MIC: pactl lists a "source-output" for every stream that is reading from a
# source. Monitor sources are excluded — those are loopbacks of your speakers
# (what a screen recorder captures), not the microphone, and counting them
# would light the indicator during ordinary playback.
#
# CAM: there is no API for this, so this walks /proc/*/fd looking for an open
# descriptor on /dev/video*. Only this user's processes are visible, which is
# fine — browsers and meeting apps all run as the user.

MIC_ICON="󰍬"
CAM_ICON="󰄀"

mic_in_use() {
    local ids src
    ids=$(pactl list short source-outputs 2>/dev/null | awk '{print $1}')
    [ -z "$ids" ] && return 1
    for id in $ids; do
        src=$(pactl list source-outputs 2>/dev/null \
              | awk -v want="Source Output #$id" '
                  $0 ~ want {found=1}
                  found && /Source:/ {print $2; exit}')
        # Resolve the numeric source id to its name to test for ".monitor".
        name=$(pactl list short sources 2>/dev/null | awk -v s="$src" '$1==s {print $2}')
        case "$name" in
            *.monitor) continue ;;
            "") continue ;;
            *) return 0 ;;
        esac
    done
    return 1
}

cam_in_use() {
    local target
    for fd in /proc/[0-9]*/fd/*; do
        target=$(readlink "$fd" 2>/dev/null) || continue
        case "$target" in
            /dev/video*) return 0 ;;
        esac
    done
    return 1
}

case "$1" in
    mic)
        if mic_in_use; then
            printf '{"text":"%s","class":"active","tooltip":"Microphone in use"}\n' "$MIC_ICON"
        else
            printf '{"text":"","class":"idle","tooltip":""}\n'
        fi
        ;;
    cam)
        if cam_in_use; then
            printf '{"text":"%s","class":"active","tooltip":"Camera in use"}\n' "$CAM_ICON"
        else
            printf '{"text":"","class":"idle","tooltip":""}\n'
        fi
        ;;
    *)
        echo "usage: privacy.sh <mic|cam>" >&2
        exit 1
        ;;
esac
