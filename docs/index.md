# arch-hyprland-neobrutalist

A reproducible Arch Linux + Hyprland desktop with a neo-brutalist visual system: square corners,
thick black borders, a loud yellow/mint/pink palette, and monospace typography across the bar,
launcher, terminal, lock screen, and login manager.

![Desktop showcase](https://raw.githubusercontent.com/fmschulz/arch-hyprland-neobrutalist/main/assets/screenshots/v0.1.0-desktop.png)

The repo tracks the complete desktop: Hyprland (modular config), Waybar, Wofi, Mako, Kitty, Yazi,
Neovim, hyprlock/hypridle/hyprsunset, greetd/regreet, package manifests, helper scripts, and the
install/apply/doctor tooling that puts it all in place. Machine-specific values (monitors,
Bluetooth devices, weather location) live in local override files that installs create once and
never overwrite.

## Quick start

On a working Arch install with a sudo-capable user:

```bash
sudo pacman -S --needed git make
git clone https://github.com/fmschulz/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
make install
```

The [installation tutorial](tutorials/getting-started.md) walks through this end to end,
including verification and first steps inside the desktop.

## Finding your way

- **[Tutorials](tutorials/index.md)** - learning-oriented lessons. Start here if you are new.
- **[How-to guides](how-to/index.md)** - task-oriented recipes: monitors, local overrides,
  the login screen, package maintenance.
- **[Reference](reference/index.md)** - keybinds, make targets, script inventory, repo layout.
- **[Explanation](explanation/index.md)** - the design system and how the pieces fit together.
