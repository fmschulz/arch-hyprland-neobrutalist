#!/bin/bash
# USB device monitor for waybar
# Shows connected USB storage devices

get_usb_devices() {
    # Get USB block devices (excludes system drives)
    lsblk -o NAME,TRAN,SIZE,MOUNTPOINT -J 2>/dev/null | jq -r '
        .blockdevices[] |
        select(.tran == "usb") |
        "\(.name) \(.size) \(.mountpoint // "not mounted")"
    ' 2>/dev/null
}

usb_info=$(get_usb_devices)
usb_count=$(echo "$usb_info" | grep -c . 2>/dev/null || echo 0)

if [ "$usb_count" -gt 0 ] && [ -n "$usb_info" ]; then
    # Build tooltip with device info
    tooltip="USB Devices:\\n"
    while IFS= read -r line; do
        [ -n "$line" ] && tooltip+="• $line\\n"
    done <<< "$usb_info"
    tooltip+="\\nClick to open file manager"

    # Output JSON for waybar
    echo "{\"text\": \"🔌 $usb_count\", \"tooltip\": \"$tooltip\", \"class\": \"connected\"}"
else
    # No USB devices - output empty to hide module
    echo "{\"text\": \"\", \"tooltip\": \"\", \"class\": \"disconnected\"}"
fi
