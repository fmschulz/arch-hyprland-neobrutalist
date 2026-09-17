# Desktop architecture

## Hyprland configuration

`~/.config/hypr/hyprland.lua` loads numbered Lua files from `conf.d/`:

| Section | Purpose |
| --- | --- |
| `00-monitors.lua` | Load the local `monitors.lua` layout |
| `10-env.lua` | Set toolkit, cursor, and locale variables |
| `20-autostart.lua` | Start desktop services and handle reloads |
| `30-look.lua` | Set gaps, borders, animations, and layout |
| `40-input.lua` | Configure the keyboard, touchpad, and gestures |
| `50-binds.lua` | Define shortcuts |
| `60-submaps.lua` | Define move and resize modes |
| `70-windowrules.lua` | Place dialogs, scratchpads, and picture-in-picture windows |

The look section reads `theme.lua`, a symlink maintained by `theme-set.sh`.
The local monitor file is installed once. Device names and layouts belong there,
outside the tracked configuration. Legacy `.conf` files use their own
`monitors.conf` and `theme.conf`.

## Bar and control panels

`ags-shell.sh login` starts Waybar, then starts AGS. It waits for AGS to report
readiness before stopping Waybar. If the supervised AGS process exits, the helper
restores Waybar. The supervisor uses a lock and checks the process identity before
stopping an instance.

AGS provides workspace buttons, window titles, status modules, a system tray, and
panels for Wi-Fi, audio, displays, appearance, notifications, and power. Its code
lives in `~/.config/ags`. The pinned AGS/Astal runtime is separate, under
`~/.local/share/arch-hypr-neobrutalist/ags`.

The bar reads network names, notifications, window titles, and battery values from
the running session. These values are not shipped in the repository.
Display changes use a confirmation timer so an unconfirmed preview can restore
the previous layout.

## Session services

Startup imports the display environment into the systemd user manager and starts
the bar, Mako, the policy agent, clipboard watchers, hypridle, and the display
helpers. The wallpaper helper starts `hyprpaper.service` and restores the selected
image. Optional sunset and on-screen-display commands run when installed.

Locking goes through `secure-lock.sh`, which clears clipboard state before
starting hyprlock. Idle actions dim, lock, turn off displays, and suspend on
battery. The battery check keeps an AC-powered machine awake at the suspend stage.

## Files and state

| Data | Location |
| --- | --- |
| Desktop configuration | `~/.config/hypr`, `ags`, `scripts`, and application directories |
| Theme fragments | `~/.config/arch-hypr-neobrutalist/themes` |
| Monitor overrides | `~/.config/hypr/monitors.lua` and legacy `monitors.conf` |
| Wallpaper collection | `~/Pictures/wallpapers` |
| Wallpaper selection | `~/.cache/wallpaper-cycle/current` |
| AGS process state | The session's `XDG_RUNTIME_DIR` |
| Local preferences | `~/.config/arch-hypr-neobrutalist` |

Credentials, Bluetooth addresses, weather coordinates, workspace notes, generated
runtime files, and caches stay on the installed machine.

## Apply and system setup

`scripts/apply.sh` merges the repository's configuration into the user's config
directories. It preserves untracked local files and excludes AGS dependencies and
build output. Local monitor templates are copied only when the corresponding
file does not exist. Theme links are initialized without replacing an existing
selection.

One-time migrations track completion in
`~/.local/state/arch-hypr-neobrutalist/migrations-applied`. Failed migrations remain
pending. `make update` pulls, installs required packages and the runtime, applies
configuration, and runs doctor. Existing legacy monitor layouts stay active until
their local configuration is converted to Lua.

Root-level setup is separate from the user configuration. Power-profile rules run
a root-owned helper under `/usr/local/lib/arch-hypr-neobrutalist`. The optional
greetd setup installs the login theme and launcher. It does not record the full
session environment in logs.
