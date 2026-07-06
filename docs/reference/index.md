# Reference

Factual description of the repo and the installed desktop. Consulted, not read.

- [Keybinds](keybinds.md) - every desktop shortcut.
- [Commands](commands.md) - make targets, installer flags, manifest format.
- [Scripts](scripts.md) - the helper script inventory.

## Repo layout

```text
configs/     Desktop, shell, and app configs synced into ~/.config
docs/        This documentation (MkDocs + Material, Diataxis structure)
packages/    Pacman and AUR package manifests
scripts/     Bootstrap, apply, doctor, and system setup scripts
wallpapers/  Wallpaper set used by the desktop and lock screen
assets/      Screenshots for the showcase
```

## Config map

| Component | Repo path | Installed to |
| --- | --- | --- |
| Hyprland | `configs/hypr/` (entry `hyprland.conf`, sections `conf.d/10-env ... 70-windowrules`) | `~/.config/hypr/` |
| hypridle / hyprlock / hyprsunset | `configs/hypr/hypridle.conf`, `hyprlock.conf`, `hyprsunset.conf` | `~/.config/hypr/` |
| Waybar | `configs/waybar/` | `~/.config/waybar/` |
| Wofi / Mako / Kitty / Yazi / btop / Neovim | `configs/<name>/` | `~/.config/<name>/` |
| Helper scripts | `configs/scripts/` | `~/.config/scripts/` |
| Bash | `configs/bash/` (hooked into `~/.bashrc`) | `~/.config/bash/` |
| systemd user units | `configs/systemd/user/` | `~/.config/systemd/user/` |
| Portal preferences | `configs/xdg-desktop-portal/portals.conf` | `~/.config/xdg-desktop-portal/` |
| regreet theme | `configs/greetd/regreet.css` | `/etc/greetd/` (via `make greetd`) |

## Machine-local files

Created once by the installer, preserved by every `make apply`, excluded from git:

| File | Purpose |
| --- | --- |
| `~/.config/hypr/monitors.conf` | Monitor layout |
| `~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf` | Trusted Bluetooth devices (`MAC\|kind\|label`) |
| `~/.config/arch-hypr-neobrutalist/welcome.conf` | Weather location for the terminal banner |
| `~/.bashrc.local` | Private shell additions |
| `~/.local/state/hypr/workspace-names.json` | Saved workspace names (written by the rename flow) |
