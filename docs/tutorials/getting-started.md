# Install the desktop

In this tutorial you install the complete desktop on a fresh Arch system and take your first
steps inside it. By the end you have Hyprland running with the neo-brutalist Waybar, launcher,
terminal, and lock screen, and you know the three keybinds that unlock everything else.

You need a working Arch Linux install (a minimal `archinstall` run is fine), a normal user with
`sudo` access, and a network connection. Everything below runs as that user.

## 1. Clone the repo

```bash
sudo pacman -S --needed git make
git clone https://github.com/fmschulz/arch-hyprland-neobrutalist.git
cd arch-hyprland-neobrutalist
```

## 2. Run the installer

```bash
make install
```

This takes a few minutes. Watch for the `sudo` password prompt near the start. The installer:

1. installs the packages in `packages/pacman.txt` (plus `packages/pacman-amd.txt` when an
   AMD GPU is detected),
2. bootstraps the `paru` AUR helper and installs `packages/aur.txt`,
3. enables NetworkManager and Bluetooth,
4. syncs all configs into `~/.config` and installs copy-once local override files,
5. applies system tuning (sysctl, journal limits, pacman cache timer, power-profile
   switching).

## 3. Verify the install

```bash
make doctor
```

Every line should print a check mark. The output ends with:

```text
All checks passed.
```

If a command or file is flagged instead, rerun `make install` and check its output for a
failed step.

## 4. Start Hyprland

Log in on a TTY and run:

```bash
Hyprland
```

The desktop appears: yellow Waybar on top, the wallpaper behind it, and a workspace indicator
on the left. (For a graphical login screen instead of the TTY, set up
[greetd/regreet](../how-to/set-up-greetd.md) afterwards.)

## 5. Take your first steps

Press these three binds - they are the core loop of the desktop (`Super` is the key with the
logo on it):

1. `Super+Return` opens a Kitty terminal. Notice the welcome banner with system info.
2. `Super+D` opens the Wofi application launcher. Type a few letters, `Esc` closes it.
3. `Super+/` opens the searchable keybinding cheatsheet. Every bind in the desktop is listed
   here - this is the page to remember.

Now try a workspace: press `Super+2` to switch, `Super+Return` to open a terminal there, and
`Super+Tab` to jump back and forth between your two workspaces. Press `Super+W` to cycle the
wallpaper, and `Super+L` to see the lock screen (your password unlocks it).

You have a working desktop.

## Next steps

- Multiple displays or a docking station: [configure monitors](../how-to/configure-monitors.md).
- Weather banner and Bluetooth auto-connect:
  [set machine-local overrides](../how-to/local-overrides.md).
- A themed login screen: [set up greetd](../how-to/set-up-greetd.md).
- The full keybind list: [keybinds reference](../reference/keybinds.md).
