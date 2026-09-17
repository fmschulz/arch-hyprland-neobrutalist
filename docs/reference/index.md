# Reference

- [Keybinds](keybinds.md): current Lua desktop shortcuts.
- [Commands](commands.md): installation, apply, doctor, and AGS development.
- [Scripts](scripts.md): desktop and session helpers.

## Configuration map

| Component | Repository path | Installed location |
| --- | --- | --- |
| Hyprland | `configs/hypr/`, entry `hyprland.lua` | `~/.config/hypr/` |
| AGS bar and panels | `configs/ags/` | `~/.config/ags/` |
| hypridle, hyprlock, hyprpaper | `configs/hypr/` | `~/.config/hypr/` |
| Waybar fallback | `configs/waybar/` | `~/.config/waybar/` |
| Wofi, Mako, Kitty, Yazi, btop, Neovim | `configs/<name>/` | `~/.config/<name>/` |
| Themes | `configs/arch-hypr-neobrutalist/themes/` | `~/.config/arch-hypr-neobrutalist/themes/` |
| Helpers | `configs/scripts/` | `~/.config/scripts/` |
| Bash | `configs/bash/` | `~/.config/bash/` |
| User services | `configs/systemd/user/` | `~/.config/systemd/user/` |
| Portal preferences | `configs/xdg-desktop-portal/` | `~/.config/xdg-desktop-portal/` |
| Login theme and launcher | `configs/greetd/` | Installed by `make greetd` |

## Local files

Monitor files are created once by apply. Create the other preference files from
the supplied examples as described in [local overrides](../how-to/local-overrides.md).
Runtime state is created by the corresponding application.

| File | Purpose |
| --- | --- |
| `~/.config/hypr/monitors.lua` | Lua monitor layout |
| `~/.config/hypr/monitors.conf` | Legacy monitor layout |
| `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf` | Bluetooth device preferences |
| `~/.config/arch-hypr-neobrutalist/welcome.conf` | Weather location |
| `~/.bashrc.local` | Private shell additions |
| `~/.local/state/hypr/` | Workspace state |
| `~/.cache/wallpaper-cycle/current` | Selected wallpaper |
