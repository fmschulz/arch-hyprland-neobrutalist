# Architecture

How the pieces fit together: what starts what, where state lives, and why the config is shaped
the way it is.

## One entry file, numbered sections

`~/.config/hypr/hyprland.conf` defines shared variables (`$mainMod`, `$terminal`, `$menu`),
sources the machine-local `monitors.conf`, and then sources seven numbered sections from
`conf.d/`:

```text
10-env.conf          environment variables
20-autostart.conf    exec-once startup chain
30-look.conf         borders, gaps, animations, groups
40-input.conf        keyboard, touchpad, per-device tuning, gestures
50-binds.conf        all keybinds
60-submaps.conf      resize submap
70-windowrules.conf  floating/centering rules for dialogs and popups
```

The numbering is load order, and load order matters: variables come first so every section can
use them, and submaps come after binds because they reference the same dispatchers. Editing a
numbered section instead of the entry file keeps machine-portable changes separate from the
monitor layout, which is the one part that differs per machine.

## The startup chain

`20-autostart.conf` starts the session: Waybar, Mako, hypridle, hyprsunset, the polkit agent
(hyprpolkitagent), clipboard watchers (`wl-paste` into cliphist, text and images only - the
primary selection is deliberately not watched so mouse selections do not flood the history),
nm-applet, udiskie (the sole automounter), the clamshell watcher, the wallpaper daemon via
`wallpaper-cycle.sh apply`, and restoration of saved workspace names.

## Idle, lock, and sleep

hypridle owns the idle timeline: at 2.5 minutes the backlight drops to minimum and the keyboard
backlight turns off (both restore on activity); at 5 minutes the session locks; at 6 minutes the
display powers off. The lock step runs through `idle-lock.sh`, which skips locking while an
external monitor is attached - a docked desk is treated as trusted, so displays still sleep but
wake without a password. Undocked, the full lock applies. Before suspend the session locks, and
after resume the display is woken explicitly so one keypress is enough. hyprlock keeps a
15-second grace window in which any key unlocks without a password.

## Screen capture is allowlisted

`ecosystem:enforce_permissions = true` makes Hyprland gate screencopy access, and the config
grants it to exactly the four binaries the desktop uses: `grim`, `grimblast`, `hyprpicker`
(grimblast's freeze mode), and `wf-recorder`, plus the desktop portal for in-app screen
sharing. Anything else that tries to read the screen triggers an explicit permission dialog.
Changing the permission list requires a Hyprland restart, not just a reload.

## Waybar and its scripts speak JSON

Custom Waybar modules exec scripts from `~/.config/scripts/` that print a single JSON object
(`text`, `tooltip`, `class`). The `class` field drives the CSS state colors (warning, critical,
pending), which is how the bar changes color without Waybar knowing anything about the
underlying checks. Two modules also listen for realtime signals so they refresh immediately
instead of waiting for their poll interval: the workspace overview on `SIGRTMIN+8` (sent by the
rename flow) and the update count on `SIGRTMIN+9` (sent after a completed upgrade).

## Portals

`portals.conf` routes portal requests by capability: the Hyprland portal serves ScreenCast and
Screenshot (it is the only one that understands the compositor), and the GTK portal serves
FileChooser (so file dialogs get a real GTK dialog). `GTK_USE_PORTAL=1` makes GTK apps such as
Firefox use the portal chooser.

## Where state lives

The config directories are disposable - `make apply` can rewrite them at any time - so anything
that must survive an apply lives elsewhere:

| Data | Location |
| --- | --- |
| Workspace names | `~/.local/state/hypr/workspace-names.json` |
| Wallpaper index | `~/.cache/wallpaper-cycle/index` |
| Weather cache (15 min TTL) | `~/.cache/arch-hypr-neobrutalist-weather.json` |
| Screenshots / recordings | `~/Documents/screenshots`, `~/Documents/screenrecordings` |
| Local overrides | `~/.config/arch-hypr-neobrutalist/`, `~/.config/hypr/monitors.conf` |

## Services and system hooks

User units (enabled by `make apply`): the pipewire stack, a weekly `cache-cleanup.timer`,
`ssh-agent.service` (backing the `SSH_AUTH_SOCK` the shell exports), and
`bluetooth-autoconnect.service` when a device list exists. System-level (installed by
`make system` as root): sysctl memory tuning, journald size limits, a weekly `paccache` timer,
and a udev rule that switches the power profile on AC/battery changes - the rule runs a
root-owned copy of the script from `/usr/local/lib/arch-hypr-neobrutalist/`, never a file from
`$HOME`, because udev executes it as root.

## The apply model

`scripts/apply.sh` merges rather than mirrors: it rsyncs tracked configs over the installed
ones but never deletes files it does not know about, and the machine-local files are installed
only when missing. The result is that `make apply` is always safe to run - it converges the
tracked parts and leaves local state alone. `make doctor` is the companion check that the
wiring (commands, files, hooks) is actually in place.

Deletions and system-level cleanup are what rsync cannot express, so those live in
`migrations/`: one-shot shell scripts that apply runs exactly once per machine, recording
applied names in `~/.local/state/arch-hypr-neobrutalist/migrations-applied`. A migration
that fails (for example, one that needs sudo in a non-interactive run) stays pending and
retries on the next apply. `make update` chains the whole convergence: pull, apply with
migrations, doctor.

## Theming is symlink indirection

Every themed surface reads its colors through a fixed path that is really a symlink into
`~/.config/arch-hypr-neobrutalist/themes/<name>/`: Waybar and Wofi `@import "theme.css"`
(GTK named colors), Hyprland and hyprlock `source` a fragment defining `$themeAccent`,
`$themeAccentText`, and `$themeBorder`, Mako `include`s a color fragment, and Kitty
`include`s a palette file. `theme-set.sh` retargets the five symlinks and reloads Hyprland,
Waybar (`SIGUSR2` re-reads CSS), and Mako - an atomic switch with no file rewriting. The
semantic colors (pink for urgent, mint for healthy, purple for submaps) stay constant
across themes; only the identity accent rotates.
