#!/usr/bin/env bash
# CPU load + temperature + memory in one compact module.
# Only the load percentage is shown on the bar; everything else lives in the
# tooltip, which is what keeps the bar narrow.

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-cpu-state"

# /proc/stat line 1: cpu user nice system idle iowait irq softirq steal
read -r _ user nice system idle _ < /proc/stat
total=$((user + nice + system + idle))
busy=$((user + nice + system))

prev_total=0
prev_busy=0
[ -r "$STATE" ] && read -r prev_total prev_busy < "$STATE"
printf '%s %s\n' "$total" "$busy" > "$STATE"

d_total=$((total - prev_total))
d_busy=$((busy - prev_busy))
# First run (or counter reset) has no meaningful delta.
if [ "$d_total" -le 0 ]; then
    pct=0
else
    pct=$((100 * d_busy / d_total))
fi
[ "$pct" -lt 0 ] && pct=0
[ "$pct" -gt 100 ] && pct=100

# Absolute path: hwmonN numbering is not stable across boots.
temp_file=$(echo /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
temp="--"
if [ -r "$temp_file" ]; then
    temp=$(($(cat "$temp_file") / 1000))
fi

mem=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2}
           END { printf "%.1fG / %.1fG", (t-a)/1048576, t/1048576 }' /proc/meminfo)

class="normal"
if [ "$temp" != "--" ]; then
    [ "$temp" -ge 80 ] && class="warm"
    [ "$temp" -ge 92 ] && class="critical"
fi

printf '{"text":"%s%% %s°C","percentage":%s,"tooltip":"CPU %s%%\\nTemperature: %s°C\\nMemory: %s","class":"%s"}\n' \
    "$pct" "$temp" "$pct" "$pct" "$temp" "$mem" "$class"
