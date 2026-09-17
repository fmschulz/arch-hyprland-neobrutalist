#!/bin/bash

# Show Hyprland keybindings in a scrollable popup (yad/zenity fallback to less)
# Keep this in sync with ~/.config/hypr/conf.d/50-binds.conf and 60-submaps.conf.

set -euo pipefail

render_section() {
  local title="$1"
  local rows="$2"

  printf '%s\n' "$title"
  printf '%s\n' "$(printf '%*s' "${#title}" '' | tr ' ' '-')"
  column -t -s '|' <<<"$rows"
  printf '\n'
}

build_keybindings_text() {
  local launch window sizing nav workspaces monitors screenshots media themes kitty mouse

  launch="$(cat <<'EOF'
Super + Return|Open terminal (Kitty)
Super + E|File manager (yazi in Kitty)
Super + D|Application launcher (Wofi)
Super + / or F1|Show this keybindings cheatsheet
Super + C|Clipboard history
Super + ;|Emoji picker
Super + Shift + P|Color picker (hex -> clipboard)
Super + Ctrl + I|Wi-Fi menu
Super + Ctrl + Shift + I|Wi-Fi login page
Super + L  /  Super + Alt + L|Lock screen
Super + Alt + P|Power menu
Super + Alt + R|Reload Hyprland config
Super + Ctrl + N|Clear notifications
Super + M|Exit Hyprland
EOF
)"

  window="$(cat <<'EOF'
Super + Q|Close active window
Super + Shift + V|Toggle floating
Super + V|Move mode (arrows or h/j/k/l)
Super + R|Resize mode (arrows or h/j/k/l)
Super + P|Toggle pseudo-tiling
Super + J|Toggle split direction
Super + F|Toggle fullscreen
Super + G|Toggle group (tabbed stack)
Super + Ctrl + G|Cycle window within group
Super + Shift + Alt + G|Lock active group
Super + `|Toggle scratchpad terminal
Super + Shift + `|Send window to scratchpad
EOF
)"

  sizing="$(cat <<'EOF'
Super + Shift + H|Halve width
Super + Ctrl + H|Double width
Super + Shift + C|Center floating window
EOF
)"

  nav="$(cat <<'EOF'
Alt + Shift + arrows|Focus window (left/right/up/down)
Super + Alt + arrows|Nudge floating window
Super + Shift + Alt + arrows|Swap window with neighbor
EOF
)"

  workspaces="$(cat <<'EOF'
Super + Tab|Last (back-and-forth) workspace
Super + Left/Right|Previous/next workspace
Super + 1-9,0|Switch to workspace 1-10
Super + Shift + Left/Right|Move window to previous/next workspace
Super + Shift + 1-9,0|Move window to workspace 1-10
Super + S|Toggle special workspace
Super + Ctrl + S|Move window to special workspace
Super + Shift + Up|Workspace overview
Super + Shift + Space|Workspace notes menu
Super + Shift + N|Workspace notes menu
EOF
)"

  monitors="$(cat <<'EOF'
Super + . / ,|Move window to next/previous monitor
Super + Shift + . / ,|Move workspace to next/previous monitor
Super + Ctrl + . / ,|Focus next/previous monitor
Super + Ctrl + M|Monitor connection menu
EOF
)"

  screenshots="$(cat <<'EOF'
Print|Region -> ~/Documents/screenshots + clipboard
Super + Print|Full screen -> clipboard
Super + Shift + Print|Region -> ~/Documents/screenshots + clipboard
Super + Ctrl + Print|Full screen -> ~/Documents/screenshots
Super + Shift + F12|Region -> ~/Documents/screenshots + clipboard
Super + Alt + S|Region -> ~/Documents/screenshots + clipboard
Ctrl + Alt + S|Region -> ~/Documents/screenshots + clipboard
Super + Shift + S|Region (camera-key shortcut)
Shift + Print|Area recording toggle -> ~/Documents/screenrecordings
Super + Shift + R|Area recording toggle -> ~/Documents/screenrecordings
EOF
)"

  media="$(cat <<'EOF'
Volume Up/Down/Mute|Output volume (with OSD)
Mic Mute|Toggle microphone
Brightness Up/Down|Screen brightness (with OSD)
Play/Pause|Play/pause media (playerctl)
Next/Previous|Next/previous track (playerctl)
EOF
)"

  themes="$(cat <<'EOF'
Super + W|Next wallpaper
Super + Shift + W|Previous wallpaper
Super + Ctrl + W|Random wallpaper
Super + Ctrl + T|Cycle desktop theme (8 themes)
EOF
)"

  kitty="$(cat <<'EOF'
Ctrl + Shift + T|New tab
Ctrl + Shift + Q|Close tab
Ctrl + Shift + Enter|New window/split
Ctrl + Shift + W|Close window/split
Ctrl + Shift + Left/Right|Previous/next tab
Ctrl + Shift + [/]|Previous/next split
Ctrl + Alt + 1-8|Kitty theme (Yellow, Blue, Purple, Green, Orange, Black, Dark Grey, White)
EOF
)"

  mouse="$(cat <<'EOF'
Super + Left Drag|Move window
Super + Right Drag|Resize window
Super + Scroll|Switch workspaces
3-finger swipe|Switch workspaces
EOF
)"

  {
    printf '%s\n' "HYPRLAND KEYBINDINGS"
    printf '%s\n\n' "===================="
    render_section "Launchers & system" "$launch"
    render_section "Window management" "$window"
    render_section "Sizing" "$sizing"
    render_section "Navigation" "$nav"
    render_section "Workspaces" "$workspaces"
    render_section "Monitors" "$monitors"
    render_section "Screenshots & recording" "$screenshots"
    render_section "Media & brightness" "$media"
    render_section "Wallpapers & themes" "$themes"
    render_section "Kitty tabs & themes" "$kitty"
    render_section "Mouse & touchpad" "$mouse"
  }
}

show_with_yad() {
  command -v yad >/dev/null 2>&1 || return 1
  printf '%s' "$1" | yad --center --title="Hyprland Keybindings" --width=900 --height=760 --text-info --wrap --margins=16 --fontname="JetBrains Mono 11" --button=gtk-close:0
}

show_with_zenity() {
  command -v zenity >/dev/null 2>&1 || return 1
  printf '%s' "$1" | zenity --text-info --title="Hyprland Keybindings" --width=900 --height=760 --font="JetBrains Mono 11" --ok-label="Close"
}

show_with_wofi() {
  command -v wofi >/dev/null 2>&1 || return 1
  # Esc closes, typing filters, scrolling works; no pager keys to learn.
  # Selecting a row just closes the menu (Esc makes wofi exit 1 - fine either way).
  printf '%s\n' "$1" \
    | sed -e '/^[[:space:]]*$/d' -e '/^-\{2,\}$/d' -e '/^=\{2,\}$/d' -e '/^HYPRLAND KEYBINDINGS$/d' \
    | wofi --dmenu --prompt "Keybindings (type to filter, Esc closes)" \
        --width 980 --height 640 --cache-file /dev/null --insensitive >/dev/null \
    || true
}

show_with_kitty() {
  command -v kitty >/dev/null 2>&1 || return 1
  local tmp
  tmp=$(mktemp) || return 1
  printf '%s\n' "$1" >"$tmp"
  # Pager fallback chain: an unguarded "less" makes the kitty window die
  # instantly ("command not found") and the popup just flashes when less is
  # not installed. more (util-linux) pages from the top; cat+read is last resort.
  # shellcheck disable=SC2016 # $1 belongs to the inner shell.
  kitty --class keybindings-popup --title "Hyprland Keybindings" \
    sh -c 'if command -v less >/dev/null 2>&1; then less -R "$1";
           elif command -v more >/dev/null 2>&1; then more "$1"; printf "\n[Enter to close] "; read -r _;
           else cat "$1"; printf "\n[Enter to close] "; read -r _; fi; rm -f "$1"' sh "$tmp"
}

main() {
  local payload
  payload="$(build_keybindings_text)"

  # From a Hyprland bind stdout is not a tty: show a wofi menu (Esc closes,
  # search filters); fall back to a kitty pager window, then yad/zenity.
  if [[ ! -t 1 ]]; then
    show_with_wofi "$payload" && exit 0
    show_with_kitty "$payload" && exit 0
  fi

  show_with_yad "$payload" && exit 0
  show_with_zenity "$payload" && exit 0

  if command -v less >/dev/null 2>&1; then
    printf '%s\n' "$payload" | less -R
  else
    printf '%s\n' "$payload"
  fi
}

main "$@"
