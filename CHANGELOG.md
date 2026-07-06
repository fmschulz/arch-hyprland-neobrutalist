# Changelog

## Unreleased

- add an atomic theme system: eight accent themes (yellow default, blue,
  purple, green, orange, black, darkgrey, white) switch Waybar, Hyprland
  borders, Wofi, Mako, hyprlock, and Kitty together via per-app fragments
  behind fixed symlinks; `Super+Ctrl+T` cycles, `theme-set.sh` picks by name
- add one-shot migrations (`migrations/`, run once per machine by apply) and
  `make update` (pull + apply + doctor), so existing installs converge on
  deletions and system cleanup that rsync cannot express
- add a master desktop menu on `Super+Alt+Space` (`desktop-menu.sh`): apps,
  capture (screenshot/recording/color picker), style (theme/wallpaper),
  toggles (Waybar, night light), and system actions

- replace the terminal radio (radio.sh + station list) with
  [bester-ytm](https://github.com/fmschulz/bester-ytm), a YouTube Music TUI
  installed as a `uv` tool by `make apply`; `Super+Shift+M` and the `ytm`
  alias open it, and `make doctor` checks the install
- `Super+Shift+R` toggles area screen recording (same script as
  `Super+Alt+Print`)

Sync the public baseline to the live daily-driver desktop (the source of
truth), keeping machine-specifics as overridable examples and personal data out.

- restructure Hyprland into a modular layout: `hyprland.conf` sources
  `conf.d/10-env … 70-windowrules`; monitors move to a preserved local override
- rework Waybar to the current visual system: Nerd Font iconography (no emoji),
  white module fields with accent-colored state, submap/mode indicator, `network`
  module, and a custom clock that opens a calendar popup
- refresh window look: 4px yellow active border, blur off, themed window groups,
  newer `monitorv2` / `windowrule match:` syntax, resize submap with on-screen notify
- add desktop scripts: `screenshot` (grimblast), `screenrecord` (wf-recorder),
  `clock-waybar`, `calendar-open`/`calendar-tui`, `updates-waybar`,
  `keybindings-popup` (`Super+/` cheatsheet), `package-snapshot`
- add `hyprsunset` night color temperature and `xdg-desktop-portal` preference config
- make the welcome-banner weather location machine-local (`welcome.conf`); the public
  tree ships no coordinates and the banner is off until a location is set
- packages: add `htop`, `vulkan-icd-loader`, `hyprsunset`, and AUR `grimblast-git`;
  drop `obsidian` (`awww` already provides the wallpaper backend)
- narrow the baseline to the desktop itself: drop bundled toolchain packages
  (`pixi`, `apptainer`, `quarto`) and their shell aliases, plus the optional
  voice-dictation add-on, so the repo stays a focused Hyprland setup
- add `cache-cleanup` user timer; align `bluetooth-autoconnect` restart policy
- refresh `hypridle`/`hyprlock`/`wofi`/`regreet` styling; extend `doctor.sh` checks
- update README, DESIGN, and KEYBINDS to match the synced setup

Critical-review fixes (2026-07-05):

- installer: strip full-line comments when parsing package manifests (a `# ...`
  line previously reached `pacman -S` as a target and aborted the install)
- packages: repair stale AUR names (`claude-code`, `electron-youtube-music-bin`,
  `captive-browser-git`; drop `clippy`, `nil`, `tuigreet`), move now-official
  packages (`hyprpolkitagent`, `wf-recorder`, `uv`, `ruff`, `eslint`, `prettier`,
  `typescript-language-server`, `gofumpt`, `choose`, `xh`, `grex`) into
  `pacman.txt`, add `xdg-desktop-portal-gtk` (portals.conf FileChooser backend)
  and `hyprpicker` (grimblast freeze), drop unused duplicates (`hyprpaper`,
  `wlsunset`, `polkit-gnome`, `swappy`, `xdg-desktop-portal-wlr`, `thermald`)
- hypridle: track the config as `configs/hypr/hypridle.conf` — hypridle only
  reads `~/.config/hypr/hypridle.conf`, so the old location was never loaded
- remove the udev USB automounter: `systemd-udevd` runs with private mounts,
  so its mounts never reached the user session; `udiskie` owns automounting
- hyprland: allow `wf-recorder`/`hyprpicker` screencopy under
  `ecosystem:enforce_permissions`; drop the bare-F1 cheatsheet grab and the
  primary-selection clipboard watcher; add playerctl media-key binds
- waybar: emit real newlines in script tooltips, sample CPU over 300 ms instead
  of since-boot, survive `checkupdates` exit 2, autodetect the battery, refresh
  the update count right after `pacman -Syu`
- wifi-menu: prompt for Wi-Fi passwords via wofi (`nmcli --ask` has no TTY)
- hyprlock: use the shipped `wallpaper.png`; regreet: derive the greeter
  runtime dir from its uid instead of hardcoding `/run/user/950`
- system tuning: install the power-profile udev hook root-owned under
  `/usr/local/lib` instead of running a `$HOME` script as root
- bash: rename the `reset`/`ya` alias footguns to `fixportals`/`pup`, drop the
  shadowed `ssh()` duplicate, fix the `fshow` Enter binding, ship an
  `ssh-agent` user service for the exported `SSH_AUTH_SOCK`
- scripts: volume OSD via mako, 15-min weather cache for the welcome banner,
  `max-fullscreen.sh` floating detection, workspace overview special-workspace
  guard, `package-snapshot.sh` now diffs against the real manifests

## v0.1.0 - 2026-04-18

- establish the first public repo layout for the Arch Hyprland neo-brutalist setup
- add tracked Neovim config so the editor is part of the reproducible baseline
- add terminal radio selector with a default KALX station list
- move monitor layout into a local override file instead of the tracked Hyprland config
- preserve local state on `make apply` instead of deleting generated or machine-specific files
- document the design system and public keybind surface
