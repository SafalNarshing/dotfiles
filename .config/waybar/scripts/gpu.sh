#!/usr/bin/env bash
# RTX 4070 load for waybar. Only the utilisation percentage reaches the bar;
# temperature and VRAM stay in the tooltip to keep the module narrow.
# nvidia-smi exits non-zero when the dGPU is powered down, so degrade quietly.
out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
                 --format=csv,noheader,nounits 2>/dev/null | tr -d ',') || out=""
read -r util temp mem_used mem_total <<EOF
$out
EOF

# nvidia-smi prints some failures to STDOUT rather than stderr — notably
# "Failed to initialize NVML: Driver/library version mismatch" after a driver
# upgrade but before a reboot. An empty-check alone lets that text through as
# a value and emits malformed JSON, which makes waybar drop the module
# entirely. So require actual digits before trusting the reading.
case "$util$temp" in
    ''|*[!0-9]*)
        echo '{"text":"--","percentage":0,"tooltip":"dGPU unavailable","class":"off"}'
        exit 0
        ;;
esac

class="normal"
[ "$temp" -ge 70 ] && class="warm"
[ "$temp" -ge 82 ] && class="critical"

printf '{"text":"%s%% %s°C","percentage":%s,"tooltip":"RTX 4070 %s%%\\nTemperature: %s°C\\nVRAM: %s / %s MiB","class":"%s"}\n' \
    "$util" "$temp" "$util" "$util" "$temp" "$mem_used" "$mem_total" "$class"
