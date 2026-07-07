#!/usr/bin/env bash
# System drift doctor: verifies that settings which must survive reboots are
# actually persisted, and that the daemons this desktop depends on are alive.
# Every check here is a failure mode that actually happened: runtime-only
# kernel params lost on reboot, PAM wiring that never existed, services dead
# because their config file was missing, .pacnew drift.
#
# Modes:
#   system-doctor.sh            human report, exit 1 if anything failed
#   system-doctor.sh --waybar   one-line JSON for a waybar custom module;
#                               empty text when healthy so the module hides
set -uo pipefail # no -e: one failing check must not kill the report

MODE=human
[[ "${1:-}" == "--waybar" ]] && MODE=waybar

FAILS=()

pass() { [[ "$MODE" == human ]] && printf '✓ %s\n' "$1"; }
fail() {
  FAILS+=("$1")
  [[ "$MODE" == human ]] && printf '✖ %s\n' "$1"
}

# --- kernel params persisted -------------------------------------------------
p=/sys/module/hid_apple/parameters/swap_opt_cmd
if [[ -r "$p" ]]; then
  runtime="$(cat "$p")"
  persisted="$(grep -rhs 'options hid_apple' /etc/modprobe.d/ 2>/dev/null |
    grep -o 'swap_opt_cmd=[01]' | cut -d= -f2 | tail -1)"
  if [[ "$runtime" == "0" || "$runtime" == "${persisted:-0}" ]]; then
    pass "hid_apple swap_opt_cmd persisted ($runtime)"
  elif compgen -G '/etc/modprobe.d/*hid_apple*' >/dev/null; then
    # A config file exists but is not world-readable; trust its presence.
    pass "hid_apple swap_opt_cmd config present (unreadable, value unverified)"
  else
    fail "hid_apple swap_opt_cmd=$runtime is runtime-only (persist in /etc/modprobe.d or lose it on reboot)"
  fi
fi

# --- PAM / system wiring -----------------------------------------------------
if grep -qs pam_gnome_keyring /etc/pam.d/system-login; then
  pass "gnome-keyring PAM auto-unlock wired"
else
  fail "gnome-keyring not in /etc/pam.d/system-login (keyring prompts will return; run configure-keyring-unlock.sh)"
fi

if [[ -f /etc/udev/rules.d/99-ignore-avrcp-power-keys.rules ]]; then
  pass "udev AVRCP power-key rule installed"
else
  fail "udev AVRCP rule missing (Bluetooth audio devices can phantom-suspend the system)"
fi

if [[ -f /etc/systemd/logind.conf.d/50-no-suspend-keys.conf ]]; then
  pass "logind suspend-key drop-in installed"
else
  fail "logind 50-no-suspend-keys.conf missing (peripheral sleep keys can suspend the system)"
fi

# --- session daemons ---------------------------------------------------------
if pgrep -x hypridle >/dev/null; then
  pass "hypridle running"
else
  fail "hypridle not running (no idle lock/dpms)"
fi

if [[ -r /proc/acpi/button/lid/LID0/state ]]; then
  if pgrep -f 'clamshell-mode.sh' >/dev/null; then
    pass "clamshell watcher running"
  else
    fail "clamshell watcher not running (lid state will not reconcile)"
  fi
fi

if systemctl --user is-enabled --quiet bluetooth-autoconnect.service 2>/dev/null; then
  conf="${XDG_CONFIG_HOME:-$HOME/.config}/arch-hypr-neobrutalist/bluetooth-devices.conf"
  if [[ -f "$conf" ]]; then
    pass "bluetooth-autoconnect has its device list"
  else
    fail "bluetooth-autoconnect enabled but bluetooth-devices.conf missing (it will silently do nothing)"
  fi
fi

# --- hyprland config health --------------------------------------------------
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  errs="$(hyprctl configerrors 2>/dev/null | grep -c 'error' || true)"
  if [[ "$errs" -eq 0 ]]; then
    pass "hyprland config parses clean"
  else
    fail "hyprland has $errs config error(s) (hyprctl configerrors)"
  fi
fi

# --- package drift -----------------------------------------------------------
n="$(find /etc -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null | wc -l)"
if [[ "$n" -eq 0 ]]; then
  pass "no .pacnew/.pacsave drift in /etc"
else
  fail "$n .pacnew/.pacsave file(s) in /etc (run pacdiff before they bite)"
fi

kpkg="$(pacman -Q linux-zen 2>/dev/null | awk '{print $2}')"
if [[ -n "$kpkg" ]]; then
  norm_pkg="${kpkg//.zen/-zen}"           # 7.1.2.zen3-1 -> 7.1.2-zen3-1
  norm_run="$(uname -r)"                  # 7.1.2-zen3-1-zen -> 7.1.2-zen3-1
  norm_run="${norm_run%-zen}"
  if [[ "$norm_pkg" == "$norm_run" ]]; then
    pass "running kernel matches installed"
  else
    fail "kernel updated ($kpkg) but running $(uname -r) — reboot pending"
  fi
fi

# --- hardware care -----------------------------------------------------------
bat=/sys/class/power_supply/BAT1
if [[ -r "$bat/status" && -r "$bat/capacity" ]]; then
  status="$(cat "$bat/status")"
  cap="$(cat "$bat/capacity")"
  if [[ "$status" == "Not charging" || "$status" == "Full" ]] && [[ "$cap" -ge 98 ]]; then
    fail "battery parked at ${cap}% on AC — set a BIOS charge limit (Advanced > Battery) to spare the cell"
  else
    pass "battery not parked at full charge"
  fi
fi

# NOTE: `cmd | grep -q` is a trap here — with pipefail, grep -q exiting early
# SIGPIPEs the producer and the pipeline fails even on a match. grep without
# -q reads all input, so these use >/dev/null instead.
if command -v fprintd-list >/dev/null 2>&1; then
  if fprintd-list "$USER" 2>/dev/null | grep ' - #' >/dev/null; then
    pass "fingerprint enrolled"
  else
    fail "fingerprint reader present but nothing enrolled (fprintd-enroll)"
  fi
fi

if lsmod 2>/dev/null | grep '^mt7921e' >/dev/null; then
  if systemctl is-enabled --quiet wifi-resume-heal.service 2>/dev/null; then
    pass "wifi resume self-heal enabled"
  else
    fail "mt7921e present but wifi-resume-heal.service not enabled (run configure-wifi-heal.sh)"
  fi
fi

# --- report ------------------------------------------------------------------
if [[ "$MODE" == waybar ]]; then
  if ((${#FAILS[@]} == 0)); then
    printf '{"text":""}\n'
  else
    printf '%s\n' "${FAILS[@]}" |
      jq -Rsc --arg t "✖ ${#FAILS[@]}" '{text:$t, tooltip:(rtrimstr("\n")), class:"warn"}'
  fi
  exit 0
fi

echo
if ((${#FAILS[@]} == 0)); then
  echo "All checks passed."
else
  echo "${#FAILS[@]} issue(s) found."
  exit 1
fi
