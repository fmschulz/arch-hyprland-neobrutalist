import { For, createComputed, createState, onCleanup } from "ags"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"
import type { NetworkController, WifiAccessPoint, WifiConnectResult } from "./network"

function securityLabel(ap: WifiAccessPoint): string {
  if (ap.security === "open") return "Open"
  if (ap.security === "owe") return "Enhanced Open"
  if (ap.security === "personal") return ap.saved ? "Saved" : "Password"
  if (ap.security === "enterprise") return "802.1X"
  return "Unsupported"
}

export function WifiPanel({ network }: { network: NetworkController }) {
  let passwordEntry!: Gtk.PasswordEntry
  let searchEntry: Gtk.SearchEntry | undefined
  let focusSource = 0
  let requestGeneration = 0
  const [selected, setSelected] = createState<WifiAccessPoint | null>(null)
  const [passwordVisible, setPasswordVisible] = createState(false)
  const [query, setQuery] = createState("")
  const controlsEnabled = createComputed(() => network.available && !network.busy() && !network.scanning())
  const scanEnabled = createComputed(() => network.available && network.enabled() && controlsEnabled())
  const filteredAccessPoints = createComputed(() => {
    const needle = query().trim().toLocaleLowerCase()
    return needle ? network.accessPoints().filter(ap => ap.name.toLocaleLowerCase().includes(needle)) : network.accessPoints()
  })

  function clearPassword() {
    requestGeneration += 1
    if (focusSource) GLib.source_remove(focusSource)
    focusSource = 0
    passwordEntry.set_text("")
    setPasswordVisible(false)
    setSelected(null)
  }

  function focusPassword() {
    if (focusSource) GLib.source_remove(focusSource)
    focusSource = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      focusSource = 0
      if (passwordVisible()) {
        passwordEntry.grab_focus()
        passwordEntry.select_region(0, -1)
      }
      return GLib.SOURCE_REMOVE
    })
  }

  function handleResult(ap: WifiAccessPoint, result: WifiConnectResult) {
    if (result.connected) {
      clearPassword()
    } else if (result.needsPassword) {
      setSelected(ap)
      setPasswordVisible(true)
      focusPassword()
    } else {
      clearPassword()
    }
  }

  async function choose(ap: WifiAccessPoint) {
    clearPassword()
    const generation = requestGeneration
    setSelected(ap)
    const result = await network.connect(ap)
    if (generation === requestGeneration) handleResult(ap, result)
  }

  async function submitPassword() {
    const ap = selected()
    if (!ap) return
    const generation = requestGeneration
    const result = await network.connect(ap, passwordEntry.get_text())
    if (generation === requestGeneration) handleResult(ap, result)
  }

  function cancelPassword() {
    network.clear()
  }

  const unsubscribeClear = network.onClear(() => {
    clearPassword()
    searchEntry?.set_text("")
    setQuery("")
  })
  onCleanup(() => {
    unsubscribeClear()
    if (focusSource) GLib.source_remove(focusSource)
  })

  return <box orientation={Gtk.Orientation.VERTICAL} spacing={12} cssClasses={["page", "wifi-page"]}>
    <box spacing={8}>
      <label label="WI-FI" xalign={0} hexpand cssClasses={["section-title"]}/>
      <switch
        active={network.enabled}
        sensitive={controlsEnabled}
        tooltipText="Turn Wi-Fi on or off"
        onStateSet={(_self, value) => {
          void network.setWifiEnabled(value)
          return true
        }}/>
      <button
        sensitive={scanEnabled}
        onClicked={() => void network.scan()}>
        <box spacing={6}>
          <Gtk.Spinner visible={network.scanning} spinning={network.scanning}/>
          <label label={network.scanning(value => value ? "Scanning…" : "Refresh")}/>
        </box>
      </button>
    </box>

    <Gtk.SearchEntry
      $={entry => { searchEntry = entry }}
      visible={network.enabled(value => network.available && value)}
      placeholderText="Search networks"
      onSearchChanged={entry => setQuery(entry.get_text())}/>

    <revealer revealChild={passwordVisible} transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        <label
          label={selected(ap => ap ? `Password for ${ap.name}` : "Wi-Fi password")}
          xalign={0}
          ellipsize={Pango.EllipsizeMode.END}
          maxWidthChars={36}
          cssClasses={["section-title"]}/>
        <Gtk.PasswordEntry
          $={entry => { passwordEntry = entry }}
          showPeekIcon
          placeholderText="Password"
          sensitive={network.busy(value => !value)}
          onActivate={() => void submitPassword()}/>
        <box spacing={8} halign={Gtk.Align.END}>
          <button label="Cancel" sensitive={network.busy(value => !value)} onClicked={cancelPassword}/>
          <button label="Connect" sensitive={network.busy(value => !value)} onClicked={() => void submitPassword()}/>
        </box>
      </box>
    </revealer>

    <label
      visible={network.status(Boolean)}
      label={network.status}
      wrap
      wrapMode={Pango.WrapMode.WORD_CHAR}
      maxWidthChars={44}
      xalign={0}
      cssClasses={["feedback"]}/>

    <label visible={!network.available} label="Wi-Fi unavailable." xalign={0} cssClasses={["hint"]}/>
    <label visible={network.enabled(value => network.available && !value)} label="Wi-Fi is off." xalign={0} cssClasses={["hint"]}/>
    <box visible={network.enabled(value => network.available && value)} orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      <label
        visible={filteredAccessPoints(points => points.length === 0)}
        label={query(value => value ? "No matching networks." : "No networks found.")}
        xalign={0}
        cssClasses={["hint"]}/>
      <For each={filteredAccessPoints}>
        {(ap: WifiAccessPoint) => <button
          tooltipText={ap.name}
          cssClasses={ap.active ? ["wifi-network", "active"] : ["wifi-network"]}
          sensitive={controlsEnabled}
          onClicked={() => void choose(ap)}>
          <box spacing={8}>
            <image iconName={ap.iconName}/>
            <label label={ap.name} xalign={0} hexpand ellipsize={Pango.EllipsizeMode.END} maxWidthChars={24}/>
            <label label={`${ap.strength}%`}/>
            <label label={ap.active ? "Connected" : securityLabel(ap)}/>
          </box>
        </button>}
      </For>
    </box>
  </box>
}
