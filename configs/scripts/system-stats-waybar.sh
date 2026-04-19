#!/usr/bin/env bash
# Combined system stats for waybar with detailed hover tooltip

# Get CPU usage
cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}')

# Get memory usage
mem_info=$(free -b | grep Mem)
mem_used=$(echo "$mem_info" | awk '{print $3}')
mem_total=$(echo "$mem_info" | awk '{print $2}')
mem_percent=$((mem_used * 100 / mem_total))
mem_used_gb=$(awk "BEGIN {printf \"%.1f\", $mem_used / 1073741824}")
mem_total_gb=$(awk "BEGIN {printf \"%.1f\", $mem_total / 1073741824}")

# Get swap info
swap_info=$(free -b | grep Swap)
swap_used=$(echo "$swap_info" | awk '{print $3}')
swap_total=$(echo "$swap_info" | awk '{print $2}')
swap_used_gb=$(awk "BEGIN {printf \"%.1f\", $swap_used / 1073741824}")
swap_total_gb=$(awk "BEGIN {printf \"%.1f\", $swap_total / 1073741824}")

# Get temperature (try multiple sources)
temp=""
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp=$((temp / 1000))
elif [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
    temp=$(cat /sys/class/hwmon/hwmon0/temp1_input)
    temp=$((temp / 1000))
else
    temp=$(sensors 2>/dev/null | grep -E "^(CPU|Tctl|Package)" | head -1 | awk '{print $2}' | tr -d '+°C')
fi

# Get disk usage for /home
disk_info=$(df -B1 /home 2>/dev/null | tail -1)
disk_used=$(echo "$disk_info" | awk '{print $3}')
disk_total=$(echo "$disk_info" | awk '{print $2}')
disk_percent=$((disk_used * 100 / disk_total))
disk_used_gb=$(awk "BEGIN {printf \"%.0f\", $disk_used / 1073741824}")
disk_total_gb=$(awk "BEGIN {printf \"%.0f\", $disk_total / 1073741824}")
disk_free_gb=$(awk "BEGIN {printf \"%.0f\", ($disk_total - $disk_used) / 1073741824}")

# Determine icon based on overall system load
if [ "$cpu_usage" -gt 80 ] || [ "$mem_percent" -gt 80 ] || [ "${temp:-0}" -gt 75 ]; then
    icon="🔥"
    class="critical"
elif [ "$cpu_usage" -gt 50 ] || [ "$mem_percent" -gt 60 ] || [ "${temp:-0}" -gt 60 ]; then
    icon="📊"
    class="warning"
else
    icon="💻"
    class="normal"
fi

# Create compact display text
text="$icon ${cpu_usage}% ${mem_percent}% ${temp:-?}°"

# Create detailed tooltip
tooltip="━━━━━ System Status ━━━━━\n"
tooltip+="🧠 CPU: ${cpu_usage}%\n"
tooltip+="🐏 RAM: ${mem_used_gb}G / ${mem_total_gb}G (${mem_percent}%)\n"
tooltip+="💫 Swap: ${swap_used_gb}G / ${swap_total_gb}G\n"
tooltip+="🌡️ Temp: ${temp:-N/A}°C\n"
tooltip+="━━━━━━━━━━━━━━━━━━━━━━━━\n"
tooltip+="💽 Disk /home: ${disk_used_gb}G / ${disk_total_gb}G (${disk_percent}%)\n"
tooltip+="   Free: ${disk_free_gb}G"

# Output JSON for waybar
printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$text" "$tooltip" "$class"
