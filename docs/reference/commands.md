# Commands

## Make targets

| Target | Effect |
| --- | --- |
| `make install` | Packages + configs + system tuning (`scripts/install.sh`) |
| `make full-install` | `make install` plus greetd/regreet setup |
| `make packages` | Install the package manifests only |
| `make apply` | Sync repo configs into `~/.config` and `~/Pictures` |
| `make doctor` | Check that the setup is wired correctly |
| `make system` | Re-run system tuning (sysctl, journal, paccache, power profile) |
| `make greetd` | Configure greetd/regreet as the login manager |

## `scripts/install.sh` options

| Flag | Effect |
| --- | --- |
| `--packages-only` | Install pacman/AUR packages, skip configs and system tuning |
| `--configs-only` | Apply configs only, skip packages |
| `--skip-aur` | Skip AUR bootstrap and `aur.txt` |
| `--skip-system` | Skip root-level system tuning |
| `--with-greetd` | Also configure greetd/regreet (same as `WITH_GREETD=1`) |

## What `make apply` does

`scripts/apply.sh` is idempotent and safe to rerun at any time:

1. rsyncs each `configs/<name>/` directory into `~/.config/<name>/` (existing extra files in
   those directories are left in place; nothing is deleted),
2. syncs wallpapers into `~/Pictures/wallpapers/`,
3. installs the copy-once local `monitors.conf` only when missing,
4. marks `~/.config/scripts/*` executable,
5. hooks `~/.config/bash/bashrc` into `~/.bashrc` (once),
6. enables user services: pipewire stack, `cache-cleanup.timer`, `ssh-agent.service`, and
   `bluetooth-autoconnect.service` when a device list exists,
7. syncs Yazi plugins (`ya pkg install`) and refreshes tldr in the background.

## What `make doctor` checks

`scripts/doctor.sh` verifies required commands on `PATH` (Hyprland, kitty, waybar, mako, wofi,
grimblast, wf-recorder, hyprlock, hypridle, ...), a wallpaper backend (`awww` or `swww`), the
presence of key installed configs (including `~/.config/hypr/hypridle.conf` and
`monitors.conf`), the bashrc hook, and workspace-name state preservation. Exit status is `0`
when every check passes.

## Manifest format

`packages/pacman.txt`, `packages/pacman-amd.txt`, and `packages/aur.txt` contain one package
name per line. Blank lines are ignored; `#` starts a comment, either on its own line or after
a package name:

```text
hyprland
grim        # screenshots
# section header comments are fine too
```

`pacman-amd.txt` is applied only when `lspci` reports an AMD/Radeon GPU.
