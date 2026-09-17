local main_mod = "SUPER"
local terminal = "kitty"
local file_manager = "kitty -e yazi"
local menu = [[sh -lc 'pkill -x wofi || exec wofi -c ~/.config/wofi/config -s ~/.config/wofi/style.css']]

-- Window management
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind(main_mod .. " + M", hl.dsp.exit())
hl.bind(main_mod .. " + V", hl.dsp.exec_cmd([[sh -lc 'hyprctl dispatch submap move && hyprctl notify -1 1600 "rgb(06FFA5)" "Move mode: arrows/hjkl move — Super+V, Esc or Return exits"']]))
hl.bind(main_mod .. " + SHIFT + V", hl.dsp.window.float())
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
hl.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd([[sh -lc 'hyprctl dispatch submap resize && hyprctl notify -1 1600 "rgb(8338EC)" "Resize mode: arrows/hjkl resize — Super+R, Esc or Return exits"']]))

-- Window sizing. The typed Lua resize dispatcher has no percentage form.
hl.bind(main_mod .. " + SHIFT + H", hl.dsp.exec_cmd([[hyprctl dispatch resizeactive "-50% 0"]]))
hl.bind(main_mod .. " + CTRL + H", hl.dsp.exec_cmd([[hyprctl dispatch resizeactive "100% 0"]]))
hl.bind(main_mod .. " + SHIFT + C", hl.dsp.window.center())

-- Groups
hl.bind(main_mod .. " + G", hl.dsp.group.toggle())
hl.bind(main_mod .. " + CTRL + G", hl.dsp.group.next())
hl.bind(main_mod .. " + SHIFT + ALT + G", hl.dsp.group.lock_active({ action = "toggle" }))

-- Application shortcuts
hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + slash", hl.dsp.exec_cmd("~/.config/scripts/keybindings-popup.sh"))
hl.bind(main_mod .. " + F1", hl.dsp.exec_cmd("~/.config/scripts/keybindings-popup.sh"))
hl.bind(main_mod .. " + XF86AudioMute", hl.dsp.exec_cmd("~/.config/scripts/keybindings-popup.sh"))
hl.bind("F1", hl.dsp.exec_cmd("~/.config/scripts/keybindings-popup.sh"))
hl.bind(main_mod .. " + CTRL + I", hl.dsp.exec_cmd("~/.config/scripts/wifi-menu.sh"))
hl.bind(main_mod .. " + CTRL + SHIFT + I", hl.dsp.exec_cmd("~/.config/scripts/wifi-portal.sh open"))

-- Scratchpad terminal
hl.bind(main_mod .. " + grave", hl.dsp.workspace.toggle_special("scratch"))
hl.bind(main_mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- Color and emoji pickers
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd([[sh -lc 'command -v hyprpicker >/dev/null 2>&1 || exit 0; c=$(hyprpicker -f hex) || exit 0; [ -n "$c" ] || exit 0; printf %s "$c" | wl-copy; notify-send "Color copied" "$c"']]))
hl.bind(main_mod .. " + semicolon", hl.dsp.exec_cmd([[sh -lc 'command -v bemoji >/dev/null 2>&1 && exec bemoji -t -n -P "wofi --dmenu --prompt Emoji -c ~/.config/wofi/config -s ~/.config/wofi/style.css"']]))

-- Clipboard history
hl.bind(main_mod .. " + C", hl.dsp.exec_cmd([[sh -lc 'cliphist list | wofi --dmenu -c ~/.config/wofi/config -s ~/.config/wofi/style.css | cliphist decode | wl-copy']]))

-- Wallpaper and desktop themes
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper-cycle.sh next"))
hl.bind(main_mod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper-cycle.sh prev"))
hl.bind(main_mod .. " + CTRL + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper-cycle.sh random"))
hl.bind(main_mod .. " + CTRL + T", hl.dsp.exec_cmd("~/.config/scripts/theme-set.sh next"))

-- Focus movement
hl.bind("ALT + SHIFT + left", hl.dsp.focus({ direction = "left" }), { repeating = true })
hl.bind("ALT + SHIFT + right", hl.dsp.focus({ direction = "right" }), { repeating = true })
hl.bind("ALT + SHIFT + up", hl.dsp.focus({ direction = "up" }), { repeating = true })
hl.bind("ALT + SHIFT + down", hl.dsp.focus({ direction = "down" }), { repeating = true })

-- Window nudging
hl.bind(main_mod .. " + ALT + left", hl.dsp.window.move({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + ALT + right", hl.dsp.window.move({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + ALT + up", hl.dsp.window.move({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(main_mod .. " + ALT + down", hl.dsp.window.move({ x = 0, y = 40, relative = true }), { repeating = true })

-- Swap windows
hl.bind(main_mod .. " + SHIFT + ALT + left", hl.dsp.window.swap({ direction = "left" }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + ALT + right", hl.dsp.window.swap({ direction = "right" }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + ALT + up", hl.dsp.window.swap({ direction = "up" }), { repeating = true })
hl.bind(main_mod .. " + SHIFT + ALT + down", hl.dsp.window.swap({ direction = "down" }), { repeating = true })

-- Workspace switching
hl.bind(main_mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(main_mod .. " + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + right", hl.dsp.focus({ workspace = "e+1" }))
for index = 1, 10 do
    local key = index % 10
    hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = index }))
end

-- Move window to workspace
hl.bind(main_mod .. " + SHIFT + left", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(main_mod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "e+1" }))
for index = 1, 10 do
    local key = index % 10
    hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = index }))
end
hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special(""))
hl.bind(main_mod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special" }))

-- Workspace overview and notes
hl.bind(main_mod .. " + SHIFT + up", hl.dsp.exec_cmd("~/.config/scripts/workspace-overview.sh"))
hl.bind(main_mod .. " + SHIFT + SPACE", hl.dsp.exec_cmd("~/.config/scripts/workspace-notes.sh menu"))
hl.bind(main_mod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/scripts/workspace-notes.sh menu"))

-- Monitor management
hl.bind(main_mod .. " + period", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(main_mod .. " + comma", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(main_mod .. " + SHIFT + period", hl.dsp.exec_cmd("hyprctl dispatch moveworkspacetomonitor current +1"))
hl.bind(main_mod .. " + SHIFT + comma", hl.dsp.exec_cmd("hyprctl dispatch moveworkspacetomonitor current -1"))
hl.bind(main_mod .. " + CTRL + period", hl.dsp.focus({ monitor = "r" }))
hl.bind(main_mod .. " + CTRL + comma", hl.dsp.focus({ monitor = "l" }))
hl.bind(main_mod .. " + CTRL + M", hl.dsp.exec_cmd("~/.config/scripts/monitor-connect.sh"))

-- Notifications and mouse
hl.bind(main_mod .. " + CTRL + N", hl.dsp.exec_cmd("~/.config/scripts/clear-notifications.sh"))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize())

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))
hl.bind(main_mod .. " + Print", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh copy-output"))
hl.bind(main_mod .. " + SHIFT + Print", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))
hl.bind(main_mod .. " + CTRL + Print", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-output"))
hl.bind(main_mod .. " + SHIFT + F12", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))
hl.bind(main_mod .. " + ALT + S", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))
hl.bind("CTRL + ALT + S", hl.dsp.exec_cmd("~/.config/scripts/screenshot.sh save-area"))

-- Screen recording
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.config/scripts/screenrecord.sh"))
hl.bind(main_mod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/scripts/screenrecord.sh"))

-- System actions
hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("~/.config/scripts/secure-lock.sh"))
hl.bind(main_mod .. " + ALT + L", hl.dsp.exec_cmd("~/.config/scripts/secure-lock.sh"))
hl.bind(main_mod .. " + ALT + P", hl.dsp.exec_cmd("~/.config/scripts/power-menu.sh"))
hl.bind(main_mod .. " + ALT + R", hl.dsp.exec_cmd("~/.config/scripts/reload.sh"))

-- Lid switch
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/scripts/clamshell-mode.sh closed"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/scripts/clamshell-mode.sh open"), { locked = true })

-- Volume and brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --output-volume raise; then exit 0; fi; exec ~/.config/scripts/volume-control.sh up']]), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --output-volume lower; then exit 0; fi; exec ~/.config/scripts/volume-control.sh down']]), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --output-volume mute-toggle; then exit 0; fi; exec ~/.config/scripts/volume-control.sh mute']]), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --input-volume mute-toggle; then exit 0; fi; exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle']]), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --brightness raise; then exit 0; fi; exec brightnessctl set +5%']]), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd([[sh -lc 'if command -v swayosd-client >/dev/null 2>&1 && swayosd-client --brightness lower; then exit 0; fi; exec brightnessctl set 5%-']]), { locked = true, repeating = true })

-- Media playback
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })
