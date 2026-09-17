# How to set up the greetd login screen

The greetd/regreet theme uses a yellow login card with thick black borders.
Set it up after the desktop works, since it replaces your login manager.

## Steps

1. From the repo checkout, run:

   ```bash
   make greetd
   ```

   For a new installation, `make full-install` includes this step.

   The script installs `greetd`, `greetd-regreet`, `seatd`, and `cage`; writes
   `/etc/greetd/config.toml` and `/etc/greetd/regreet.toml`; deploys the stylesheet to
   `/etc/greetd/regreet.css`; adds your user and the `greeter` user to the `seat` group;
   enables `seatd` and `greetd` for the next boot; and sets the default boot target
   to graphical. It does not restart the display manager in the current session.

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
