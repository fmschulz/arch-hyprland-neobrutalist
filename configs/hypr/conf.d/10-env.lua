-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")

-- Wayland / toolkit
hl.env("GTK_USE_PORTAL", "1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- Locale
hl.env("LANG", "C.UTF-8")
hl.env("LC_TIME", "C.UTF-8")

-- Firefox: native Wayland backend so clipboard works reliably
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("MOZ_DBUS_REMOTE", "1")
