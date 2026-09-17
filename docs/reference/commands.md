# Commands

## Make targets

| Target | Effect |
| --- | --- |
| `make install` | Install packages, prepare the AGS runtime, apply configs, and tune the system |
| `make full-install` | Install the desktop and configure greetd/regreet |
| `make packages` | Install package manifests |
| `make apply` | Merge configuration into `~/.config` and wallpapers into `~/Pictures/wallpapers` |
| `make update` | Pull, install required packages and runtime, apply configuration, then run doctor |
| `make doctor` | Check commands, configuration, and the AGS runtime |
| `make system` | Apply system tuning |
| `make greetd` | Install the themed login manager |

## Installer flags

| Flag | Effect |
| --- | --- |
| `--packages-only` | Install packages without applying configuration or system tuning |
| `--configs-only` | Apply configuration without installing packages |
| `--skip-aur` | Skip the AUR helper and package manifest |
| `--skip-system` | Skip root-level system tuning |
| `--with-greetd` | Configure greetd/regreet |

## Apply behavior

`scripts/apply.sh` merges tracked configuration without deleting local files.
It copies the monitor templates only when their local counterparts are missing,
initializes theme links, marks desktop helpers executable, adds the Bash source
line, runs pending migrations, and enables the configured user services.

An existing legacy installation keeps using `hyprland.conf` until a local
`monitors.lua` exists, preserving its custom monitor layout.
See [monitor migration](../how-to/configure-monitors.md#legacy-configuration).

AGS dependencies, generated type declarations, and build output are excluded
from the configuration copy. `make apply` does not build the AGS runtime; the
installer handles that step. Machines managed through a controlcenter checkout
must use that checkout's deployer instead.

## AGS runtime and development

The pinned runtime is installed under
`~/.local/share/arch-hypr-neobrutalist/ags`. To prepare it directly:

```bash
./scripts/install-ags.sh
```

After it is installed, validate the AGS sources from the repository root:

```bash
cd configs/ags
npm ci
npm run types
npm run check
. "$HOME/.local/share/arch-hypr-neobrutalist/ags/env.sh"
npm run build
```

The typecheck should exit without diagnostics; the build writes a bundle
under `dist/`. The desktop starts from the TypeScript source. The generated files
and `node_modules` are ignored by Git.

`AGS_RUNTIME_ENV` can select a different runtime environment file for isolated
checks. Load that same environment before running the AGS build command.

## Doctor and package manifests

`make doctor` checks installed commands, the active configuration and theme,
wallpaper integration, the Bash source line, and the AGS runtime. It reports
missing requirements and returns a nonzero exit status if any check fails.

Manifests contain one package name per line. Blank lines and `#` comments are
ignored. `packages/pacman-amd.txt` is installed only when the system reports an
AMD/Radeon GPU.
