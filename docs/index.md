# arch-hyprland-neobrutalist

An Arch Linux desktop based on the Framework 12 setup, with square corners,
black borders, eight accent palettes, and monospace text.

Hyprland loads modular Lua configuration. An AGS 3 bar provides controls for
Wi-Fi, audio, displays, appearance, notifications, and power; Waybar is the
fallback. The desktop also includes Wofi, Mako, Kitty, hyprlock, hypridle,
hyprpaper, and an optional greetd/regreet login screen.

The public configuration uses generic monitor defaults. Device identifiers,
credentials, network profiles, workspace notes, and runtime state are not part
of the distribution.

## Install

Start from an up-to-date x86-64 Arch installation with a user that can run `sudo`:

```bash
sudo pacman -S --needed git make
git clone https://github.com/fmschulz/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
make install
make doctor
```

The [installation tutorial](tutorials/getting-started.md) covers first login and
verification. The configuration is checked with Hyprland 0.56.2 and AGS 3.1.2.

## Guides

- [Tutorials](tutorials/index.md): install and start the desktop.
- [How-to guides](how-to/index.md): configure monitors, themes, local settings,
  and the login screen.
- [Reference](reference/index.md): shortcuts, commands, and scripts.
- [Explanation](explanation/index.md): architecture and visual design.
