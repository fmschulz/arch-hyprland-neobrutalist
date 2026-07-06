# How to set up the greetd login screen

The repo ships a neo-brutalist theme for greetd/regreet: a yellow login card with thick black
borders that matches the rest of the desktop. Setting it up replaces your current login manager,
so do this after the desktop itself works.

## Steps

1. From the repo checkout, run:

   ```bash
   make greetd
   ```

   (Fresh installs can do everything in one shot with `make full-install` instead of
   `make install`.)

   The script installs `greetd`, `greetd-regreet`, `seatd`, and `cage`; writes
   `/etc/greetd/config.toml` and `/etc/greetd/regreet.toml`; deploys the stylesheet to
   `/etc/greetd/regreet.css`; adds your user and the `greeter` user to the `seat` group;
   enables `seatd` and `greetd`; and sets the default boot target to graphical.

2. Reboot:

   ```bash
   sudo reboot
   ```

## Verify

After the reboot, VT1 shows the themed regreet screen. Selecting the Hyprland session and
entering your password lands in the desktop.

## Revert

To go back to TTY login:

```bash
sudo systemctl disable --now greetd.service
```

The greetd config files under `/etc/greetd/` are inert while the service is disabled.
