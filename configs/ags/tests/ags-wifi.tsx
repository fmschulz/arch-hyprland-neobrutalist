// Fake-controller UI test. It never constructs the production NetworkManager controller.
// From the repository root, run:
// source ~/.local/share/arch-hypr-neobrutalist/ags/env.sh
// cd configs/ags
// ags bundle --gtk 4 tests/ags-wifi.tsx ../../../tasks/ags-wifi-test.js
// Verify which socket belongs to the nested compositor before setting both values:
// WAYLAND_DISPLAY=wayland-2 AGS_TEST_DISPLAY=wayland-2 timeout 20s ../../../tasks/ags-wifi-test.js
// AGS_TEST_KEYBOARD=gtk runs the remaining workflow with controlled entry text; it does not prove keyboard injection.

import { createState } from "ags"
import app from "ags/gtk4/app"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"
import { WifiPanel } from "../Wifi"
import type { NetworkController, WifiAccessPoint, WifiConnectResult } from "../network"

const TEST_PASSWORD = "test-password-never-print"
const WRONG_PASSWORD = "wrong-password-never-print"

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message)
}

function nextTurn(): Promise<void> {
  return new Promise(resolve => {
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      resolve()
      return GLib.SOURCE_REMOVE
    })
  })
}

function wait(milliseconds: number): Promise<void> {
  return new Promise(resolve => {
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, milliseconds, () => {
      resolve()
      return GLib.SOURCE_REMOVE
    })
  })
}

function waitForWindowActive(window: Gtk.Window): Promise<void> {
  if (window.is_active) return Promise.resolve()
  return new Promise((resolve, reject) => {
    const signalId = window.connect("notify::is-active", () => {
      if (!window.is_active) return
      GLib.source_remove(timeoutId)
      window.disconnect(signalId)
      resolve()
    })
    const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2_000, () => {
      window.disconnect(signalId)
      reject(new Error("The nested compositor did not activate the test window"))
      return GLib.SOURCE_REMOVE
    })
  })
}

function waitForProcess(process: Gio.Subprocess): Promise<void> {
  return new Promise((resolve, reject) => {
    process.wait_check_async(null, (_source, result) => {
      try {
        process.wait_check_finish(result)
        resolve()
      } catch (error) {
        reject(error)
      }
    })
  })
}

function descendants(root: Gtk.Widget): Gtk.Widget[] {
  const found: Gtk.Widget[] = []
  for (let child = root.get_first_child(); child; child = child.get_next_sibling()) {
    found.push(child, ...descendants(child))
  }
  return found
}

function fakeNetwork() {
  const point: WifiAccessPoint = {
    id: "personal-psk:74657374",
    name: "Test network",
    strength: 80,
    iconName: "network-wireless-signal-excellent-symbolic",
    active: false,
    saved: false,
    security: "personal",
  }
  const [summary] = createState("Wi-Fi")
  const [enabled, setEnabled] = createState(true)
  const [scanning, setScanning] = createState(false)
  const [busy] = createState(false)
  const [status, setStatus] = createState("")
  const [accessPoints, setAccessPoints] = createState([
    point,
    { ...point, id: "personal-psk:6f74686572", name: "Other test network with a deliberately long name", strength: 60 },
    { ...point, id: "owe:616972706f7274", name: "Airport test network", security: "owe" as const },
  ])
  const clearCallbacks = new Set<() => void>()
  const attempts: Array<string | undefined> = []
  const toggles: boolean[] = []

  const network: NetworkController = {
    summary,
    enabled,
    scanning,
    busy,
    status,
    accessPoints,
    async scan() {
      setScanning(true)
    },
    async setWifiEnabled(value) {
      toggles.push(value)
      setEnabled(value)
    },
    async connect(selectedPoint, password): Promise<WifiConnectResult> {
      attempts.push(password)
      if (selectedPoint.security === "owe") {
        assert(password === undefined, "Enhanced Open received a password")
        setStatus("Connected to Airport test network.")
        return { connected: true, needsPassword: false }
      }
      if (!password) {
        setStatus("Enter the password for Test network.")
        return { connected: false, needsPassword: true }
      }
      if (password === WRONG_PASSWORD) {
        setStatus("Authentication failed for Test network. Check the password and retry.")
        return { connected: false, needsPassword: true }
      }
      setStatus("Connected to Test network.")
      return { connected: true, needsPassword: false }
    },
    clear() {
      setStatus("")
      for (const callback of clearCallbacks) callback()
    },
    onClear(callback) {
      clearCallbacks.add(callback)
      return () => clearCallbacks.delete(callback)
    },
    dispose() {
      clearCallbacks.clear()
    },
  }
  return {
    network,
    attempts,
    toggles,
    setScanning,
    updateStrength() {
      setAccessPoints(points => points.map(ap => ({ ...ap, strength: ap.strength - 1 })))
    },
  }
}

async function run(
  window: Gtk.Window,
  harness: ReturnType<typeof fakeNetwork>,
) {
  const { network, attempts, toggles } = harness
  window.present()
  await waitForWindowActive(window)
  const widgets = descendants(window)
  const entry = widgets.find(widget => widget instanceof Gtk.PasswordEntry) as Gtk.PasswordEntry | undefined
  const search = widgets.find(widget => widget instanceof Gtk.SearchEntry) as Gtk.SearchEntry | undefined
  const toggle = widgets.find(widget => widget instanceof Gtk.Switch) as Gtk.Switch | undefined
  const spinner = widgets.find(widget => widget instanceof Gtk.Spinner) as Gtk.Spinner | undefined
  const revealer = widgets.find(widget => widget instanceof Gtk.Revealer) as Gtk.Revealer | undefined
  const buttons = widgets.filter(widget => widget instanceof Gtk.Button) as Gtk.Button[]
  const cancelButton = buttons.find(button => button.get_label() === "Cancel")
  const connectButton = buttons.find(button => button.get_label() === "Connect")
  const networkButtons = () => descendants(window)
    .filter(widget => widget instanceof Gtk.Button && widget.has_css_class("wifi-network")) as Gtk.Button[]
  const clickNetwork = (index = 0) => {
    const button = networkButtons()[index]
    assert(button !== undefined, `Network button ${index} is missing`)
    button.emit("clicked")
  }
  assert(entry !== undefined, "The password entry did not render")
  assert(search !== undefined && toggle !== undefined && spinner !== undefined, "The Wi-Fi controls did not render")
  assert(revealer !== undefined, "The password revealer did not render")
  assert(networkButtons().length === 3, "The network buttons did not render")
  assert(cancelButton !== undefined && connectButton !== undefined, "The password action buttons did not render")
  assert(entry.get_show_peek_icon(), "The password visibility control is disabled")
  assert(search.get_next_sibling() === revealer, "The password form is not directly below the search control")
  assert(!widgets.some(widget => widget instanceof Gtk.ScrolledWindow), "The Wi-Fi panel still contains a nested scroll area")

  search.set_text("other")
  search.emit("search-changed")
  await nextTurn()
  assert(networkButtons().length === 1, "Search did not filter the network list")
  assert(networkButtons()[0].get_tooltip_text()?.startsWith("Other test network") === true, "Search retained the wrong network")
  search.set_text("")
  search.emit("search-changed")
  await nextTurn()

  harness.setScanning(true)
  await nextTurn()
  assert(spinner.get_visible() && spinner.get_spinning(), "The scan spinner did not show while scanning")
  assert(networkButtons().every(button => !button.get_sensitive()), "Network rows stayed active while scanning")
  harness.setScanning(false)
  await nextTurn()

  toggle.emit("state-set", false)
  await nextTurn()
  assert(toggles.at(-1) === false && !search.get_visible(), "The Wi-Fi switch did not request or show the disabled state")
  await network.setWifiEnabled(true)
  await nextTurn()

  clickNetwork()
  await nextTurn()
  assert(revealer.get_reveal_child(), "Selecting a protected network did not show the password input")
  const focus = window.get_focus()
  assert(focus === entry || (focus !== null && focus.is_ancestor(entry)), "The revealed password input did not receive keyboard focus")
  await wait(150)
  const keyboardMode = GLib.getenv("AGS_TEST_KEYBOARD") ?? "wtype"
  assert(keyboardMode === "wtype" || keyboardMode === "gtk", "AGS_TEST_KEYBOARD must be wtype or gtk")
  if (keyboardMode === "gtk") {
    entry.set_text("keyboard-focus-check")
  } else {
    const testDisplay = GLib.getenv("AGS_TEST_DISPLAY")
    assert(!!testDisplay && GLib.getenv("WAYLAND_DISPLAY") === testDisplay, "Set AGS_TEST_DISPLAY to the verified nested compositor socket before injecting keys")
    const keyboard = Gio.Subprocess.new(["wtype", "keyboard-focus-check"], Gio.SubprocessFlags.NONE)
    await waitForProcess(keyboard)
  }
  await nextTurn()
  assert(entry.get_text() === "keyboard-focus-check", keyboardMode === "gtk"
    ? "Controlled entry text did not reach the password field"
    : "Keyboard input did not reach the password entry")
  entry.set_text("")
  entry.set_text(TEST_PASSWORD)
  harness.updateStrength()
  await nextTurn()
  assert(entry.get_text() === TEST_PASSWORD && revealer.get_reveal_child(), "A strength update disturbed the password prompt")
  clickNetwork(1)
  await nextTurn()
  const passwordHeading = descendants(window).find(widget =>
    widget instanceof Gtk.Label && widget.get_label().startsWith("Password for Other test network")) as Gtk.Label | undefined
  assert(passwordHeading !== undefined, "The long network password heading did not render")
  assert(passwordHeading.get_ellipsize() === Pango.EllipsizeMode.END && passwordHeading.get_max_width_chars() === 36,
    "The long network password heading is not width-bounded")
  assert(entry.get_text() === "", "Changing networks retained the previous network's password")
  cancelButton.emit("clicked")
  assert(entry.get_text() === "" && !revealer.get_reveal_child(), "Cancel did not clear and hide the password")

  clickNetwork()
  await nextTurn()
  entry.set_text(WRONG_PASSWORD)
  connectButton.emit("clicked")
  await nextTurn()
  assert(revealer.get_reveal_child(), "A failed password attempt did not stay open for retry")
  assert(entry.get_text() === WRONG_PASSWORD, "A failed password attempt discarded the editable value")

  entry.set_text(TEST_PASSWORD)
  connectButton.emit("clicked")
  await nextTurn()
  assert(entry.get_text() === "" && !revealer.get_reveal_child(), "Success did not clear and hide the password")

  clickNetwork()
  await nextTurn()
  entry.set_text(TEST_PASSWORD)
  search.set_text("other")
  network.clear()
  assert(entry.get_text() === "" && !revealer.get_reveal_child(), "The panel clear hook retained the password")
  assert(search.get_text() === "" && networkButtons().length === 3, "The panel clear hook retained the network filter")

  clickNetwork()
  network.clear()
  await nextTurn()
  assert(!revealer.get_reveal_child(), "A stale connection result reopened the cleared password prompt")
  assert(attempts.length === 7, "The fake backend received an unexpected number of attempts")

  clickNetwork()
  await nextTurn()
  entry.set_text(TEST_PASSWORD)
  const enhancedOpen = networkButtons()[2]
  assert(descendants(enhancedOpen).some(widget => widget instanceof Gtk.Label && widget.get_label() === "Enhanced Open"),
    "The Enhanced Open network label did not render")
  clickNetwork(2)
  await nextTurn()
  assert(network.status() === "Connected to Airport test network.", "Enhanced Open did not reach the connect handler")
  assert(entry.get_text() === "" && !revealer.get_reveal_child(), "Enhanced Open retained or prompted for a password")
  assert(attempts.at(-1) === undefined, "Enhanced Open submitted the previous network's password")
  print("ags-wifi: PASS (Enhanced Open label, passwordless click, previous password cleared)")
  print(keyboardMode === "gtk" ? "ags-wifi: PASS (controlled entry; keyboard injection not tested)" : "ags-wifi: PASS (keyboard injection)")
  window.close()
  app.quit()
}

app.start({
  instanceName: "ags-wifi-test",
  main() {
    const harness = fakeNetwork()
    const window = <Gtk.Window application={app} visible title="AGS Wi-Fi test"><WifiPanel network={harness.network}/></Gtk.Window>
    void run(window as Gtk.Window, harness).catch(error => {
      printerr(`ags-wifi: FAIL: ${error instanceof Error ? error.message : String(error)}`)
      app.quit(1)
    })
  },
})
