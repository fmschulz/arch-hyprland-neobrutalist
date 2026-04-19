#!/bin/bash
# USB device menu for waybar - dropdown with mount/unmount/copy path options

WOFI_STYLE="--width=400 --height=300 --dmenu --prompt=USB --cache-file=/dev/null"

notify() {
    notify-send -t 3000 "USB" "$1"
}

copy_to_clipboard() {
    echo -n "$1" | wl-copy
    notify "Copied: $1"
}

mount_device() {
    local device="$1"
    result=$(udisksctl mount -b "$device" 2>&1)
    if [ $? -eq 0 ]; then
        mountpoint=$(echo "$result" | grep -oP 'at \K.*')
        notify "Mounted $device at $mountpoint"
    else
        notify "Failed to mount $device: $result"
    fi
}

unmount_device() {
    local device="$1"
    result=$(udisksctl unmount -b "$device" 2>&1)
    if [ $? -eq 0 ]; then
        notify "Unmounted $device"
    else
        notify "Failed to unmount: $result"
    fi
}

eject_device() {
    local device="$1"
    # First unmount all partitions
    for part in $(lsblk -ln -o NAME "$device" | tail -n +2); do
        udisksctl unmount -b "/dev/$part" 2>/dev/null
    done
    result=$(udisksctl power-off -b "$device" 2>&1)
    if [ $? -eq 0 ]; then
        notify "Ejected $device - safe to remove"
    else
        notify "Eject failed: $result"
    fi
}

# Get USB devices with partitions
get_usb_info() {
    lsblk -J -o NAME,SIZE,LABEL,MOUNTPOINT,TRAN,TYPE 2>/dev/null | jq -r '
        .blockdevices[] |
        select(.tran == "usb") |
        . as $parent |
        (if .children then .children[] else . end) |
        select(.type == "part" or .type == "disk") |
        "\(.name)|\(.size)|\(.label // "USB Drive")|\(.mountpoint // "")|\($parent.name)"
    ' 2>/dev/null
}

build_menu() {
    local menu=""
    local devices=$(get_usb_info)

    if [ -z "$devices" ]; then
        echo "No USB devices found"
        return
    fi

    while IFS='|' read -r name size label mountpoint parent; do
        [ -z "$name" ] && continue

        local device="/dev/$name"
        local display_name="${label:-USB Drive}"

        if [ -n "$mountpoint" ]; then
            # Device is mounted - show path and unmount options
            menu+="📂 $display_name ($size) → $mountpoint\n"
            menu+="   📋 Copy path: $mountpoint\n"
            menu+="   ⏏️  Unmount $name\n"
            menu+="   🔌 Eject /dev/$parent\n"
        else
            # Device not mounted - show mount option
            menu+="💾 $display_name ($size) - not mounted\n"
            menu+="   📥 Mount $name\n"
        fi
    done <<< "$devices"

    echo -e "$menu"
}

handle_selection() {
    local selection="$1"

    case "$selection" in
        *"Copy path:"*)
            path=$(echo "$selection" | sed 's/.*Copy path: //')
            copy_to_clipboard "$path"
            ;;
        *"Unmount"*)
            device=$(echo "$selection" | grep -oP 'Unmount \K\S+')
            unmount_device "/dev/$device"
            ;;
        *"Mount"*)
            device=$(echo "$selection" | grep -oP 'Mount \K\S+')
            mount_device "/dev/$device"
            ;;
        *"Eject"*)
            device=$(echo "$selection" | grep -oP 'Eject \K\S+')
            eject_device "$device"
            ;;
        *"→"*)
            # Clicked on mounted device line - open file manager
            path=$(echo "$selection" | grep -oP '→ \K.*')
            if [ -n "$path" ] && [ -d "$path" ]; then
                xdg-open "$path" 2>/dev/null &
            fi
            ;;
    esac
}

# Main
menu=$(build_menu)

if [ "$menu" = "No USB devices found" ]; then
    notify "No USB devices connected"
    exit 0
fi

selection=$(echo -e "$menu" | wofi $WOFI_STYLE)

if [ -n "$selection" ]; then
    handle_selection "$selection"
fi
