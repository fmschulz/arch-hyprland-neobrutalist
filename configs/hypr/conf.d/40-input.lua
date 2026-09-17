hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            middle_button_emulation = false,
            clickfinger_behavior = true,
            tap_to_click = true,
            drag_lock = false,
        },
    },
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_forever = false,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
