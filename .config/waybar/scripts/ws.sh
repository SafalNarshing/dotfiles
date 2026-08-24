#!/usr/bin/env bash
# State of one workspace, for a per-workspace waybar module.
#
# WHY NOT hyprland/workspaces: waybar's built-in module drives clicks by
# sending the legacy IPC string "dispatch workspace <n>". On a Lua Hyprland
# config every dispatch is wrapped as hl.dispatch(...) and evaluated as Lua,
# so that string is a syntax error and clicking does nothing. Waybar also does
# not substitute {name} into on-click, so it cannot be redirected either.
# One module per workspace is the way to own the click target.
#
# Usage: ws.sh <workspace-number>   ->  JSON with class active|occupied|empty

WS="${1:?usage: ws.sh <n>}"
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-ws-state"
TTL_MS=80

# Five modules poll independently; without a shared cache that is ten hyprctl
# round-trips a second. One snapshot serves them all.
now_ms=$(( $(date +%s%N) / 1000000 ))
stale=1
if [ -s "$CACHE" ]; then
    then_ms=$(head -1 "$CACHE")
    [ $(( now_ms - then_ms )) -lt "$TTL_MS" ] && stale=0
fi

if [ "$stale" -eq 1 ]; then
    {
        printf '%s\n' "$now_ms"
        hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import json,sys;print("ACTIVE",json.load(sys.stdin).get("id",0))' 2>/dev/null
        hyprctl workspaces -j 2>/dev/null | python3 -c '
import json,sys
for w in json.load(sys.stdin):
    if w.get("windows",0) > 0:
        print("OCCUPIED", w["id"])
' 2>/dev/null
    } > "$CACHE.$$" 2>/dev/null && mv "$CACHE.$$" "$CACHE" 2>/dev/null
    rm -f "$CACHE.$$"
fi

active=$(awk '/^ACTIVE/{print $2}' "$CACHE" 2>/dev/null)

if [ "$active" = "$WS" ]; then
    class="active"
elif grep -q "^OCCUPIED $WS\$" "$CACHE" 2>/dev/null; then
    class="occupied"
else
    class="empty"
fi

# A single space, NOT an empty string: waybar hides a custom module whose text
# is empty, which makes every dot disappear. The space is rendered at
# font-size 0 in style.css, so it occupies no width and min-width sets the
# dot size.
printf '{"text":" ","class":"%s","tooltip":"Workspace %s"}\n' "$class" "$WS"
