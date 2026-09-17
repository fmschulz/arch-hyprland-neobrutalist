hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})
hl.window_rule({
    name = "float-network-controls",
    match = { class = "^(nm-connection-editor|blueman-manager)$" },
    float = true,
})
hl.window_rule({
    name = "float-polkit-agents",
    match = { class = "^(org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent|polkit-gnome-authentication-agent-1)$" },
    float = true,
})
hl.window_rule({
    name = "float-file-dialogs",
    match = { title = "^(Open File.*|Save File.*|Save As.*|Choose Files.*|Choose wallpaper.*)$" },
    float = true,
})

hl.window_rule({
    name = "pip-float",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
})
hl.window_rule({
    name = "pip-pin",
    match = { title = "^(Picture-in-Picture)$" },
    pin = true,
})
hl.window_rule({
    name = "pip-aspect",
    match = { title = "^(Picture-in-Picture)$" },
    keep_aspect_ratio = true,
})
hl.window_rule({
    name = "pip-position",
    match = { title = "^(Picture-in-Picture)$" },
    move = "100%-w-30 100%-h-60",
})

hl.window_rule({
    name = "video-idle-inhibit",
    match = { class = "^(mpv|firefox|chromium|imv)$" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "scratch-float",
    match = { class = "^(scratch)$" },
    float = true,
})
hl.window_rule({
    name = "scratch-size",
    match = { class = "^(scratch)$" },
    size = "1100 600",
})
hl.window_rule({
    name = "scratch-center",
    match = { class = "^(scratch)$" },
    center = true,
})

hl.window_rule({
    name = "keybindings-popup-float",
    match = { class = "^(keybindings-popup)$" },
    float = true,
})
hl.window_rule({
    name = "keybindings-popup-size",
    match = { class = "^(keybindings-popup)$" },
    size = "1000 680",
})
hl.window_rule({
    name = "keybindings-popup-center",
    match = { class = "^(keybindings-popup)$" },
    center = true,
})

hl.window_rule({
    name = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})
