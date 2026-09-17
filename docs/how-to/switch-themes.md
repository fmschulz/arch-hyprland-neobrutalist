# Switch themes

The desktop includes yellow, blue, purple, green, orange, black, darkgrey, and
white palettes. The palette changes the AGS and Waybar accents, window borders,
launcher, notifications, and terminal colors.

## Choose a palette

Use the AGS appearance panel, press `Super+Ctrl+T` to cycle, or run:

```bash
~/.config/scripts/theme-set.sh list
~/.config/scripts/theme-set.sh blue
~/.config/scripts/theme-set.sh current
```

The last command prints `blue`. New Kitty windows use the selected palette.
For an existing Kitty window, use its `Ctrl+Alt+1` through `Ctrl+Alt+8` shortcuts.

Palette fragments live in
`~/.config/arch-hypr-neobrutalist/themes/<name>/`. The theme helper updates the
application symlinks, including `~/.config/hypr/theme.lua`, and reloads the
applications that support it. AGS observes the selected palette.

## Choose a wallpaper

Use the appearance panel or run:

```bash
~/.config/scripts/wallpaper-cycle.sh next
~/.config/scripts/wallpaper-cycle.sh prev
~/.config/scripts/wallpaper-cycle.sh random
```

Add images to `~/Pictures/wallpapers/`. Both the picker and helper use that
directory unless `WALLPAPER_DIR` is set in the desktop session environment.
The helper applies the image through `hyprpaper.service` and saves the selection
only after the active displays report it.

`Super+W`, `Super+Shift+W`, and `Super+Ctrl+W` invoke the same three actions.
