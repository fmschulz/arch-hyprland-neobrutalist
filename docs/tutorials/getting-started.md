# Install the desktop

This tutorial installs the neo-brutalist Hyprland desktop and starts its AGS bar,
launcher, terminal, and lock screen.

Use an up-to-date x86-64 Arch Linux system, a normal user with `sudo` access, and a
network connection. The configuration is checked with Hyprland 0.56.2 and AGS 3.1.2.
Run the commands as your normal user.

## 1. Clone the repository

```bash
sudo pacman -S --needed git make
git clone https://github.com/fmschulz/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
```

## 2. Install

```bash
make install
```

The installer installs the listed packages, prepares the pinned user-local AGS
runtime, enables the base services, copies desktop configuration, and applies
system tuning. The runtime build downloads verified archives and requires a
working compiler toolchain. Watch for the `sudo` prompt and any failed step.

For the themed login manager, use `make full-install` or follow the
[greetd guide](../how-to/set-up-greetd.md) after testing the desktop.

## 3. Verify

```bash
make doctor
```

A successful check ends with:

```text
All checks passed.
```

If doctor reports a missing file, command, or runtime, check the installation
output before logging in.

## 4. Start the session

From a TTY, run:

```bash
Hyprland
```

Hyprland loads `~/.config/hypr/hyprland.lua`. Waybar appears while AGS starts; the
AGS bar takes over when ready. If AGS cannot start, Waybar remains available.
The generic monitor defaults use preferred display modes. Adjust your
[local monitor layout](../how-to/configure-monitors.md) if needed.

## 5. Try the controls

1. Press `Super+Return` to open Kitty.
2. Press `Super+D` to open Wofi. Type an application name; `Esc` closes it.
3. Press `Super+/` to open the shortcut reference.
4. Click the bar's network or audio module to open its controls.
5. Press `Super+2` to select workspace 2 and `Super+Tab` to return.
6. Press `Super+Ctrl+T` to change the accent palette.

`Super+L` locks the session. Unlock with your account password. `Super+Alt+P`
opens the power menu; `Super+M` exits the session directly.

For weather preferences and Bluetooth devices, see
[local overrides](../how-to/local-overrides.md). These settings stay on your machine.
