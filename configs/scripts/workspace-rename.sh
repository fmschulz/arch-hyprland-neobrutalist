#!/usr/bin/env bash
# Workspace rename manager for Hyprland
# Uses native hyprctl renameworkspace with persistence

# Runtime state lives outside ~/.config/hypr (that dir is a symlink into the git repo)
NAMES_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/workspace-names.json"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/workspace-names.lock"

# Ensure directory exists and the file holds valid JSON (heal empty/corrupt state)
mkdir -p "$(dirname "$NAMES_FILE")"
if [ ! -s "$NAMES_FILE" ] || ! jq -e . "$NAMES_FILE" >/dev/null 2>&1; then
    echo '{}' > "$NAMES_FILE"
fi

# One-time migration from the legacy config-dir location
LEGACY_NAMES_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/workspace-names.json"
if [ -f "$LEGACY_NAMES_FILE" ]; then
    if [ "$(cat "$NAMES_FILE")" = "{}" ] && jq -e . "$LEGACY_NAMES_FILE" >/dev/null 2>&1; then
        cat "$LEGACY_NAMES_FILE" > "$NAMES_FILE"
    fi
    rm -f "$LEGACY_NAMES_FILE"
fi

# Read saved names
read_names() {
    cat "$NAMES_FILE" 2>/dev/null || echo '{}'
}

trim_name() {
    printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

extract_custom_name() {
    local ws="$1"
    local name
    name=$(trim_name "$2")

    if [ -z "$name" ] || [ "$name" = "$ws" ]; then
        echo ""
        return
    fi

    if [[ "$name" =~ ^${ws}:[[:space:]]*(.*)$ ]]; then
        trim_name "${BASH_REMATCH[1]}"
        return
    fi

    if [[ "$name" =~ ^${ws}[[:space:]]+(.+)$ ]]; then
        trim_name "${BASH_REMATCH[1]}"
        return
    fi

    echo "$name"
}

format_workspace_name() {
    local ws="$1"
    local custom_name
    custom_name=$(extract_custom_name "$ws" "$2")

    if [ -z "$custom_name" ]; then
        echo "$ws"
    else
        echo "$custom_name"
    fi
}

# Nudge the waybar module listening on signal 8
refresh_waybar() {
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

# Read-modify-write under one exclusive lock; the write goes to a temp file
# and is renamed over the target so readers always see a complete file.
# Pass an empty name to delete the entry.
update_names() {
    local ws="$1"
    local name="$2"
    (
        flock -x 200
        local current new_data
        current=$(cat "$NAMES_FILE" 2>/dev/null)
        echo "$current" | jq -e . >/dev/null 2>&1 || current='{}'
        if [ -z "$name" ]; then
            new_data=$(echo "$current" | jq --arg ws "$ws" 'del(.[$ws])')
        else
            new_data=$(echo "$current" | jq --arg ws "$ws" --arg name "$name" '.[$ws] = $name')
        fi
        if [ -n "$new_data" ] && echo "$new_data" | jq -e . >/dev/null 2>&1; then
            echo "$new_data" > "$NAMES_FILE.tmp" && mv -f "$NAMES_FILE.tmp" "$NAMES_FILE"
        fi
    ) 200>"$LOCK_FILE"
}

# Get saved name for a workspace
get_name() {
    local ws="$1"
    local saved_name
    saved_name=$(jq -r --arg ws "$ws" '.[$ws] // ""' "$NAMES_FILE" 2>/dev/null)
    extract_custom_name "$ws" "$saved_name"
}

# Rename workspace (both in Hyprland and save to file)
rename_workspace() {
    local ws="$1"
    local name
    name=$(extract_custom_name "$ws" "$2")

    if [ -z "$name" ]; then
        # Reset to number if empty
        hyprctl dispatch renameworkspace "$ws" "$ws"
    else
        # Set custom name
        hyprctl dispatch renameworkspace "$ws" "$(format_workspace_name "$ws" "$name")"
    fi
    update_names "$ws" "$name"

    refresh_waybar
}

# Show rename dialog
edit_name() {
    local ws="$1"
    local current_name
    current_name=$(get_name "$ws")

    # If no saved name, show current workspace name from Hyprland
    if [ -z "$current_name" ]; then
        current_name=$(hyprctl workspaces -j | jq -r --argjson ws "$ws" '.[] | select(.id == $ws) | .name // ""')
        current_name=$(extract_custom_name "$ws" "$current_name")
    fi

    # Use wofi for input; apply the rename if wofi exited successfully
    local new_name
    if new_name=$(echo "$current_name" | wofi --dmenu \
        --prompt "Rename workspace $ws:" \
        --width 400 \
        --height 60 \
        --lines 1 \
        2>/dev/null); then
        rename_workspace "$ws" "$new_name"
    fi
}

# Restore all saved workspace names (run on Hyprland startup)
restore_names() {
    local names
    names=$(read_names)

    # Iterate through all saved names
    echo "$names" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r ws name; do
        if [ -n "$name" ]; then
            hyprctl dispatch renameworkspace "$ws" "$(format_workspace_name "$ws" "$name")"
        fi
    done

    refresh_waybar
}

# Show workspace overview with names
show_overview() {
    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r 'sort_by(.id) | .[] | "\(.id)|\(.name)"')

    local current_ws
    current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    # One clients snapshot for the whole loop instead of one hyprctl per workspace
    local clients_json
    clients_json=$(hyprctl clients -j)

    local overview=""
    while IFS='|' read -r ws_id ws_name; do
        local apps
        apps=$(echo "$clients_json" | jq -r --argjson ws "$ws_id" '[.[] | select(.workspace.id == $ws) | .class] | unique | join(", ")' 2>/dev/null)

        local marker=""
        [ "$ws_id" = "$current_ws" ] && marker="→ "

        local custom_name
        custom_name=$(extract_custom_name "$ws_id" "$ws_name")

        if [ -n "$custom_name" ]; then
            overview+="${marker}${ws_id}:${custom_name}"
        else
            overview+="${marker}${ws_id}"
        fi
        [ -n "$apps" ] && overview+=" [$apps]"
        overview+="\n"
    done <<< "$workspaces"

    # Show with wofi
    local selected
    selected=$(echo -e "$overview" | wofi --dmenu \
        --prompt "Workspaces (select to switch, Super+A to rename)" \
        --width 500 \
        --height 400 \
        2>/dev/null)

    if [ -n "$selected" ]; then
        local ws_num
        ws_num=$(echo "$selected" | sed -E 's/^→ //' | sed -E 's/^(-?[0-9]+).*/\1/')
        # Special workspaces have negative ids; only dispatch plain numbers
        if [[ "$ws_num" =~ ^[0-9]+$ ]]; then
            hyprctl dispatch workspace "$ws_num"
        fi
    fi
}

# Generate waybar JSON output
waybar_output() {
    local current_ws
    current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

    local workspaces
    workspaces=$(hyprctl workspaces -j | jq -r 'sort_by(.id) | .[] | "\(.id)|\(.name)"')

    # One clients snapshot for the whole loop instead of one hyprctl per workspace
    local clients_json
    clients_json=$(hyprctl clients -j)

    local tooltip=$'━━━ Workspaces ━━━\n'
    while IFS='|' read -r ws_id ws_name; do
        local apps
        apps=$(echo "$clients_json" | jq -r --argjson ws "$ws_id" '[.[] | select(.workspace.id == $ws) | .class] | unique | join(", ")' 2>/dev/null)

        local marker=""
        [ "$ws_id" = "$current_ws" ] && marker="→ "

        local custom_name
        custom_name=$(extract_custom_name "$ws_id" "$ws_name")

        if [ -n "$custom_name" ]; then
            tooltip+="${marker}${ws_id}:${custom_name}"
        else
            tooltip+="${marker}${ws_id}"
        fi
        [ -n "$apps" ] && tooltip+=" [$apps]"
        tooltip+=$'\n'
    done <<< "$workspaces"
    tooltip+="━━━━━━━━━━━━━━━━━━"

    # jq escapes user-entered names and window classes so the module JSON stays valid
    jq -cn --arg tooltip "$tooltip" '{text: "󰕮", tooltip: $tooltip}'
}

# Main command handler
case "$1" in
    rename)
        rename_workspace "$2" "$3"
        ;;
    edit)
        edit_name "$2"
        ;;
    restore)
        restore_names
        ;;
    overview)
        show_overview
        ;;
    waybar)
        waybar_output
        ;;
    get)
        get_name "$2"
        ;;
    *)
        echo "Usage: $0 {rename|edit|restore|overview|waybar|get} [workspace] [name]"
        echo ""
        echo "Commands:"
        echo "  rename <ws> <name>    Rename workspace to <ws>:<name>"
        echo "  edit <ws>             Open rename dialog for workspace"
        echo "  restore               Restore all saved workspace names"
        echo "  overview              Show workspace overview menu"
        echo "  waybar                Output JSON for waybar module"
        echo "  get <ws>              Get saved name for workspace"
        exit 1
        ;;
esac
