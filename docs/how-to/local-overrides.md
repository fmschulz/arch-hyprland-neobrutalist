# How to set machine-local overrides

Machine-specific values stay out of git. Each lives in a local file that `make apply` installs
once from a tracked `.example` template and then preserves. This guide covers the four override
files besides [monitors](configure-monitors.md).

## Weather in the terminal banner

The Kitty welcome banner shows current weather and a 5-day forecast once a location is set.

1. Copy the template and edit it:

   ```bash
   cp ~/.config/arch-hypr-neobrutalist/welcome.conf.example \
      ~/.config/arch-hypr-neobrutalist/welcome.conf
   ```

2. Set your coordinates (find them via the search box on <https://open-meteo.com/>):

   ```bash
   WEATHER_CITY="Reykjavik"
   WEATHER_LAT="64.1466"
   WEATHER_LON="-21.9426"
   WEATHER_TZ="auto"
   ```

3. Open a new terminal. The banner now includes a line like
   `Reykjavik: now 11°C` and a 5-day forecast. Responses are cached for 15 minutes, so
   new tabs open instantly.

Leave `WEATHER_LAT`/`WEATHER_LON` unset to disable the weather section entirely.

## Bluetooth auto-connect

Trusted devices reconnect automatically and preferred audio sinks are promoted when
`~/.config/arch-hypr-neobrutalist/bluetooth-devices.conf` exists.

1. Create it from the template (`bluetooth-devices.conf.example` in the same directory), one
   device per line in `MAC|kind|label` form:

   ```text
   AA:BB:CC:DD:EE:FF|audio|Desktop Speakers
   11:22:33:44:55:66|hid|Trackpad
   ```

   `kind` is `audio` (also sets the A2DP profile and default sink) or `hid`.

2. Run `make apply` from the repo checkout. When the file exists, apply enables the
   `bluetooth-autoconnect.service` user unit, which reconciles connections every 30 seconds.

## Radio stations

`Super+Shift+R` opens a station selector backed by
`~/.config/arch-hypr-neobrutalist/radio-stations.tsv`. The installer seeds it with a default
list (starting with KALX). Add stations as tab-separated lines:

```text
Name<TAB>https://stream.example.org/mp3<TAB>optional note
```

Lines starting with `#` are comments. Verify with:

```bash
~/.config/scripts/radio.sh list
```

## Shell additions

`~/.bashrc.local` is sourced at the end of the tracked bashrc and is the place for private
aliases, SSH shortcuts, and extra PATH entries. `configs/bash/bashrc.local.example` shows the
pattern. Nothing in this file is ever committed.
