# How to switch themes

The desktop ships eight accent themes: yellow (default), blue, purple, green, orange,
black, darkgrey, and white. A theme recolors the Waybar background, active window border,
Wofi surfaces, Mako notifications, the hyprlock input field, and the Kitty palette in one
switch — the black borders, white module fields, and geometry stay fixed.

## Cycle or pick

- `Super+Ctrl+T` cycles to the next theme.
- `Super+Alt+Space` → Style → "Theme: pick" chooses one by name.
- From a shell:

  ```bash
  ~/.config/scripts/theme-set.sh list
  ~/.config/scripts/theme-set.sh blue
  ```

The switch is atomic and persists across reboots. Open Kitty windows keep their palette
until restyled (`Ctrl+Alt+<n>`) — new windows pick up the theme automatically.

## Verify

```bash
~/.config/scripts/theme-set.sh current
```

## How it works

Each theme is a directory of per-app fragments under
`~/.config/arch-hypr-neobrutalist/themes/<name>/`. The configs reference fixed symlinks
(`~/.config/waybar/theme.css`, `~/.config/hypr/theme.conf`, `~/.config/mako/theme`,
`~/.config/kitty/theme-current.conf`), and `theme-set.sh` retargets those symlinks and
reloads Hyprland, Waybar, and Mako.

## Add your own theme

Copy an existing fragment directory and adjust the colors, then select it by name:

```bash
cp -r ~/.config/arch-hypr-neobrutalist/themes/yellow \
      ~/.config/arch-hypr-neobrutalist/themes/mytheme
# edit the five files, then:
~/.config/scripts/theme-set.sh mytheme
```

Custom theme directories are preserved by `make apply` like any other local file.
