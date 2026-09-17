#!/usr/bin/env bash
# Workspace overview script

# Get current workspace
current_workspace=$(hyprctl activewindow | grep workspace | awk '{print $2}')

# Get all workspaces with windows
workspaces=$(hyprctl workspaces | grep "workspace ID" | awk '{print $3}' | sort -n)

# Create workspace list with titles and app names
workspace_list=""
for ws in $workspaces; do
  # Get app classes for this workspace using simpler text parsing
  app_classes=$(hyprctl clients | awk -v ws="$ws" '
    /^Window/ { in_window = 1; current_class = ""; current_ws = "" }
    in_window && /^[[:space:]]*class:/ { current_class = $2 }
    in_window && /^[[:space:]]*workspace:/ {
      current_ws = $2
      # Handle workspace format like "2 (2)"
      gsub(/\(.*\)/, "", current_ws)
      gsub(/[[:space:]]*/, "", current_ws)
    }
    in_window && /^[[:space:]]*$/ {
      if (current_ws == ws && current_class != "") {
        print current_class
      }
      in_window = 0
    }
    END {
      # Handle last window if file doesnt end with blank line
      if (in_window && current_ws == ws && current_class != "") {
        print current_class
      }
    }
  ' | sort -u | tr '\n' ', ' | sed 's/,$//')

  windows=$(hyprctl clients | grep -c "workspace: $ws")

  if [ "$windows" -gt 0 ]; then
    if [ "$ws" -eq "$current_workspace" ]; then
      workspace_list="$workspace_list$ws (current) - [$app_classes]\n"
    else
      workspace_list="$workspace_list$ws - [$app_classes]\n"
    fi
  fi
done

# Show workspace selector with wofi
selected=$(echo -e "$workspace_list" | wofi --dmenu --prompt "Select Workspace" --width 400 --height 300)

if [ -n "$selected" ]; then
  # Extract workspace number
  ws_num=$(echo "$selected" | awk '{print $1}')
  if [[ ! "$ws_num" =~ ^[1-9][0-9]*$ ]]; then
    echo "workspace-overview: invalid workspace id: $ws_num" >&2
    exit 1
  fi
  # Switch to selected workspace
  hyprctl dispatch "hl.dsp.focus({ workspace = $ws_num })"
fi
