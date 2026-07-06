# How to maintain packages

The manifests under `packages/` are the canonical package set: `pacman.txt` (official repos),
`pacman-amd.txt` (extra packages for AMD GPUs), and `aur.txt` (AUR). They are curated by hand;
`#` comments are allowed anywhere.

## Install everything from the manifests

```bash
make packages
```

This runs the pacman manifests with `--needed` (already-installed packages are skipped, so it
is safe to rerun) and the AUR manifest through `paru`, bootstrapping `paru` first if needed.

## Apply day-to-day updates

The Waybar update badge polls hourly and shows the pending count. Clicking it opens a terminal
running `sudo pacman -Syu` and refreshes the badge when the upgrade finishes. From a shell, the
`pup` alias does the same full upgrade including AUR packages (`paru -Syu`).

## Check for drift between the system and the manifests

After installing or removing packages ad hoc, see how the machine differs from the manifests:

```bash
./configs/scripts/package-snapshot.sh
```

The report has four sections: repo packages installed but missing from `pacman*.txt`, repo
packages listed but not installed, and the same pair for AUR against `aur.txt`. Example:

```text
-- Repo packages installed explicitly but not in pacman*.txt --
  + duckdb
-- Repo packages in pacman*.txt but not installed --
  - inkscape
```

Adopt or drop entries by editing `packages/*.txt` by hand, then rerun the report until the
sections you care about are empty. The script is read-only: it never modifies the manifests
or the system.
