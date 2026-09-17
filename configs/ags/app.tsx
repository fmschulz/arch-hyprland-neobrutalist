import app from "ags/gtk4/app"
import { createBinding, createComputed, createState, For, onCleanup, This } from "ags"
import { createPoll, interval } from "ags/time"
import { execAsync } from "ags/process"
import Astal from "gi://Astal?version=4.0"
import Hyprland from "gi://AstalHyprland?version=0.1"
import AstalNetwork from "gi://AstalNetwork?version=0.1"
import Tray from "gi://AstalTray?version=0.1"
import Gdk from "gi://Gdk?version=4.0"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"
import { AppearancePanel, createAppearance, script } from "./Appearance"
import { createNetwork } from "./network"
import { WifiPanel } from "./Wifi"
import { AudioPanel, createAudio } from "./Audio"
import { MediaPanel, createMedia } from "./Media"
import { NotificationsPanel, createNotifications } from "./Notifications"
import { KeepAwakePanel, createKeepAwake } from "./KeepAwake"
import { DisplayPanel, createDisplay } from "./Display"
import css from "./style.css"

type Page = "network" | "sound" | "desktop" | "appearance" | "notifications"
type UpdateStatus = { text: string; tooltip: string; class: "pending" | "none" | "error" }
type SystemStatus = { text: string; tooltip: string; class: "normal" | "warning" | "critical" | "error" }
type BluetoothStatus = { text: string; tooltip: string; class: "on" | "connected" | "off" }
type BatteryStatus = { text: string; tooltip: string; class: "normal" | "warning" | "critical" | "charging" }
const UNKNOWN_UPDATES: UpdateStatus = { text: "󰏗 ?", tooltip: "Package update status unavailable", class: "error" }
const UNKNOWN_SYSTEM: SystemStatus = { text: "󰍛", tooltip: "System status unavailable", class: "error" }
const UNKNOWN_BLUETOOTH: BluetoothStatus = { text: "󰂲", tooltip: "Bluetooth status unavailable", class: "off" }
const UNKNOWN_BATTERY: BatteryStatus = { text: " ?", tooltip: "Battery status unavailable", class: "critical" }
let togglePanel: (page?: Page, monitor?: Gdk.Monitor) => void
let ready = false

function read(path: string): string {
  try { return new TextDecoder().decode(GLib.file_get_contents(path)[1]).trim() } catch { return "" }
}

function batteryTime(path: string, status: string): string {
  const pairs = [["energy_now", "energy_full", "power_now"], ["charge_now", "charge_full", "current_now"]]
  for (const [nowName, fullName, rateName] of pairs) {
    const now = Number(read(`${path}/${nowName}`))
    const full = Number(read(`${path}/${fullName}`))
    const rate = Number(read(`${path}/${rateName}`))
    if (now <= 0 || full <= 0 || rate <= 0) continue
    const hours = (status === "Charging" ? full - now : now) / rate
    const minutes = Math.max(0, Math.round(hours * 60))
    return `${Math.floor(minutes / 60)}h ${minutes % 60}m ${status === "Charging" ? "until full" : "remaining"}`
  }
  return "Time estimate unavailable"
}

function batteryStatus(): BatteryStatus {
  const dir = Gio.File.new_for_path("/sys/class/power_supply")
  const entries = dir.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, null)
  let entry: Gio.FileInfo | null
  let batteryPath = ""
  let onAC = false
  while ((entry = entries.next_file(null))) {
    const path = `/sys/class/power_supply/${entry.get_name()}`
    const type = read(`${path}/type`)
    if (type === "Battery" && !batteryPath && read(`${path}/scope`) !== "Device") batteryPath = path
    else if (type === "Mains" && read(`${path}/online`) === "1") onAC = true
  }
  entries.close(null)
  if (!batteryPath) return { text: " AC", tooltip: "No battery detected", class: "normal" }

  const capacity = Number(read(`${batteryPath}/capacity`))
  const status = read(`${batteryPath}/status`) || "Unknown"
  const displayStatus = capacity === 100 && (status === "Full" || status === "Not charging") ? "Fully charged" : status
  const estimate = status === "Charging" || status === "Discharging" ? `\n${batteryTime(batteryPath, status)}` : ""
  const icons = ["", "", "", "", ""]
  const icon = status === "Charging" ? "" : onAC ? "" : icons[Math.min(4, Math.floor(capacity / 20))]
  const state = status === "Charging" ? "charging" : capacity <= 15 ? "critical" : capacity <= 30 ? "warning" : "normal"
  return {
    text: `${icon} ${capacity}%`,
    tooltip: `Battery: ${capacity}%\nStatus: ${displayStatus}\n${onAC ? "AC power connected" : "On battery power"}${estimate}`,
    class: state,
  }
}

function networkLabel(summary: string): string {
  if (summary.startsWith("Ethernet: ")) return ` ${summary.slice(10)}`
  const strength = summary.match(/(\d+)%$/)?.[1]
  return strength ? ` ${strength}%` : " offline"
}

function audioLabel(summary: string): string {
  if (summary === "MUTE" || summary === "AUDIO") return ""
  const volume = Number(summary.replace("%", ""))
  const icon = volume < 34 ? "" : volume < 67 ? "" : ""
  return `${icon} ${summary}`
}

async function bluetoothStatus(): Promise<BluetoothStatus> {
  try {
    const controller = await execAsync(["bluetoothctl", "show"])
    if (!/^\s*Powered:\s+yes$/m.test(controller)) return { text: "󰂲", tooltip: "Bluetooth is off", class: "off" }
    const alias = controller.match(/^\s*Name:\s+(.+)$/m)?.[1] ?? "Bluetooth"
    const devices = await execAsync(["bluetoothctl", "devices", "Connected"])
    const names = devices.split("\n").map(line => line.replace(/^Device\s+\S+\s+/, "").trim()).filter(Boolean)
    return names.length > 0
      ? { text: "󰂱", tooltip: `${alias}\nConnected: ${names.join(", ")}`, class: "connected" }
      : { text: "󰂯", tooltip: alias, class: "on" }
  } catch {
    return UNKNOWN_BLUETOOTH
  }
}

async function systemStatus(): Promise<SystemStatus> {
  try {
    const value: unknown = JSON.parse(await execAsync([script("system-stats-waybar")]))
    if (typeof value === "object" && value !== null) {
      const item = value as Record<string, unknown>
      if (typeof item.text === "string" && typeof item.tooltip === "string"
        && (item.class === "normal" || item.class === "warning" || item.class === "critical")) {
        return item as SystemStatus
      }
    }
  } catch { /* The visible error state replaces invalid or missing output. */ }
  return UNKNOWN_SYSTEM
}

type ClickActions = { primary: () => void; middle?: () => void; secondary?: () => void }

function addClickActions(widget: Gtk.Button, actions: ClickActions) {
  widget.connect("clicked", actions.primary)
  if (!actions.middle && !actions.secondary) return
  const gesture = Gtk.GestureClick.new()
  gesture.button = 0
  gesture.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
  gesture.connect("pressed", self => {
    const action = self.get_current_button() === 2 ? actions.middle : self.get_current_button() === 3 ? actions.secondary : undefined
    action?.()
  })
  widget.add_controller(gesture)
}

function addWorkspaceScroll(widget: Gtk.Widget, run: (argv: string[]) => Promise<void>) {
  const scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL | Gtk.EventControllerScrollFlags.DISCRETE)
  scroll.connect("scroll", (_self, _dx, dy) => {
    if (dy !== 0) {
      void run(["hyprctl", "dispatch", `hl.dsp.focus({ workspace = "${dy < 0 ? "e-1" : "e+1"}" })`])
    }
    return true
  })
  widget.add_controller(scroll)
}

function TrayItems() {
  return <box spacing={10} cssClasses={["tray"]}>
    <For each={createBinding(Tray.get_default(), "items")}>
      {(item: Tray.TrayItem) => <menubutton tooltipText={createBinding(item, "title")} $={button => {
        button.menuModel = item.menuModel
        button.insert_action_group("dbusmenu", item.actionGroup)
        const id = item.connect("notify::action-group", () => button.insert_action_group("dbusmenu", item.actionGroup))
        const menuId = item.connect("notify::menu-model", () => { button.menuModel = item.menuModel })
        onCleanup(() => { item.disconnect(id); item.disconnect(menuId) })
      }}><image pixelSize={18} gicon={createBinding(item, "gicon")}/></menubutton>}
    </For>
  </box>
}

function desktop() {
  const hyprland = Hyprland.get_default()
  const focusedWorkspace = createBinding(hyprland, "focusedWorkspace")
  const [urgentWorkspaces, setUrgentWorkspaces] = createState<number[]>([])
  const urgentSignal = hyprland.connect("urgent", (_service, client) => {
    const id = client.workspace?.id
    if (id && id !== hyprland.focusedWorkspace?.id) {
      setUrgentWorkspaces(current => current.includes(id) ? current : [...current, id])
    }
  })
  const focusSignal = hyprland.connect("notify::focused-workspace", () => {
    setUrgentWorkspaces(current => current.filter(id => id !== hyprland.focusedWorkspace?.id))
  })
  const workspaceSignal = hyprland.connect("notify::workspaces", () => {
    setUrgentWorkspaces(current => current.filter(id => hyprland.workspaces.some(workspace => workspace.id === id)))
  })
  const network = createNetwork()
  const networkService = AstalNetwork.get_default()
  const primaryNetwork = createBinding(networkService, "primary")
  const wiredNetwork = createBinding(networkService, "wired")
  const networkSummary = createComputed(() => primaryNetwork() === AstalNetwork.Primary.WIRED
    ? `Ethernet: ${wiredNetwork()?.device.get_iface() ?? "wired"}`
    : network.summary())
  const appearance = createAppearance()
  const audio = createAudio()
  const media = createMedia()
  const notifications = createNotifications()
  const awake = createKeepAwake()
  const display = createDisplay()
  const [page, setPage] = createState<Page>("network")
  const [error, setError] = createState("")
  const [clockAlternate, setClockAlternate] = createState(false)
  const [clock, setClock] = createState("")
  const refreshClock = (alternate = clockAlternate()) => setClock(GLib.DateTime.new_now_local().format(
    alternate ? " %Y-%m-%d" : " %a %b %d  %I:%M %p",
  )!)
  const clockTimer = interval(30000, () => refreshClock())
  refreshClock()
  const battery = createPoll<BatteryStatus>(batteryStatus(), 10000, batteryStatus)
  const bluetooth = createPoll<BluetoothStatus>(UNKNOWN_BLUETOOTH, 5000, bluetoothStatus)
  const system = createPoll<SystemStatus>(UNKNOWN_SYSTEM, 10000, systemStatus)
  const profile = createPoll("", 5000, async () => {
    try { return (await execAsync(["powerprofilesctl", "get"])).trim() } catch { return "unavailable" }
  })
  const [updates, setUpdates] = createState<UpdateStatus>(UNKNOWN_UPDATES)
  async function refreshUpdates() {
    try {
      const value: unknown = JSON.parse(await execAsync([script("updates-waybar")]))
      if (typeof value === "object" && value !== null) {
        const item = value as Record<string, unknown>
        if (typeof item.text === "string" && typeof item.tooltip === "string"
          && (item.class === "pending" || item.class === "none" || item.class === "error")) {
          setUpdates(item as UpdateStatus)
          return
        }
      }
    } catch { /* The visible error state replaces invalid or missing output. */ }
    setUpdates(UNKNOWN_UPDATES)
  }
  const updateTimer = interval(3600000, () => void refreshUpdates())
  void refreshUpdates()
  const memory = createPoll("", 10000, () => {
    const info = read("/proc/meminfo")
    const total = Number(info.match(/MemTotal:\s+(\d+)/)?.[1] ?? 0)
    const available = Number(info.match(/MemAvailable:\s+(\d+)/)?.[1] ?? 0)
    return `${((total - available) / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(0)} GiB RAM`
  })

  async function run(argv: string[]) {
    setError("")
    try { await execAsync(argv) } catch { setError("That action did not complete. Check the command or service before retrying.") }
  }

  async function installUpdates() {
    await run(["kitty", "-e", "bash", "-c", "sudo pacman -Syu; echo; echo Press any key to close...; read -n1"])
    await refreshUpdates()
  }

  function selectPage(value: Page) {
    if (value !== page()) network.clear()
    setError("")
    setPage(value)
    if (scroller) scroller.vadjustment.value = 0
    if (panel.visible && value === "network") void network.scan()
    if (value === "notifications") void notifications.refresh()
  }

  let scroller: Gtk.ScrolledWindow
  const panel = <window name="control-center" namespace="controlcenter-panel" application={app}
    anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
    exclusivity={Astal.Exclusivity.NORMAL} keymode={Astal.Keymode.ON_DEMAND}
    marginTop={8} marginRight={12} visible={false}>
    <Gtk.EventControllerKey onKeyPressed={(_self, key) => {
      if (key === Gdk.KEY_Escape) { panel.hide(); return true }
      return false
    }}/>
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["control-center"]} widthRequest={460}>
      <box cssClasses={["panel-header"]} spacing={12}>
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label label={page(value => value === "notifications" ? "NOTIFICATIONS" : "CONTROL CENTER")} xalign={0} cssClasses={["title"]}/>
          <label label="AGS / ASTAL / GTK 4" xalign={0} cssClasses={["subtitle"]}/>
        </box>
        <button label="Close" onClicked={() => panel.hide()}/>
      </box>
      <box homogeneous cssClasses={["tabs"]}>
        {(["network", "sound", "desktop", "appearance"] as const).map(tab => <button
          label={tab[0].toUpperCase() + tab.slice(1)}
          cssClasses={page(value => value === tab ? ["active"] : [])}
          onClicked={() => selectPage(tab)}/>) }
      </box>
      <Gtk.ScrolledWindow hscrollbarPolicy={Gtk.PolicyType.NEVER} overlayScrolling={false} propagateNaturalHeight
        maxContentHeight={600} $={self => { scroller = self }}>
        <box orientation={Gtk.Orientation.VERTICAL}>
          <box orientation={Gtk.Orientation.VERTICAL} visible={page(value => value === "network")}>
            <WifiPanel network={network}/>
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} visible={page(value => value === "appearance")}>
            <AppearancePanel appearance={appearance}/>
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={12} visible={page(value => value === "sound")} cssClasses={["page"]}>
            <AudioPanel audio={audio}/>
            <MediaPanel media={media}/>
            <button label="Advanced audio settings…" onClicked={() => void run(["pavucontrol"])}/>
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} visible={page(value => value === "notifications")}>
            <NotificationsPanel notifications={notifications}/>
          </box>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={12} visible={page(value => value === "desktop")} cssClasses={["page"]}>
            <button label="Notifications and Do Not Disturb" onClicked={() => selectPage("notifications")}/>
            <KeepAwakePanel awake={awake}/>
            <DisplayPanel display={display}/>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={8} cssClasses={["widget-card"]}>
            <label label="LAPTOP BRIGHTNESS" cssClasses={["section-title"]} xalign={0}/>
            <box spacing={8} homogeneous>
              <button label="Dimmer" onClicked={() => void run(["brightnessctl", "set", "5%-"])}/>
              <button label="Brighter" onClicked={() => void run(["brightnessctl", "set", "+5%"])}/>
            </box>
            <label label="POWER PROFILE" cssClasses={["section-title"]} xalign={0}/>
            <box spacing={8} homogeneous>
              {["power-saver", "balanced", "performance"].map(value => <button label={value === "power-saver" ? "Save" : value === "balanced" ? "Balanced" : "Fast"}
                cssClasses={profile(current => current === value ? ["active"] : [])}
                onClicked={() => void run(["powerprofilesctl", "set", value])}/>) }
            </box>
            <label label={battery(value => `Battery ${value.text}`)} xalign={0}/>
            <label label={memory} xalign={0} cssClasses={["hint"]}/>
            </box>
            <button label="Bluetooth devices…" onClicked={() => void run(["blueman-manager"])}/>
            <box homogeneous spacing={8}>
              <button label="Lock" onClicked={() => { panel.hide(); void run([script("secure-lock")]) }}/>
              <button label="Power menu…" onClicked={() => { panel.hide(); void run([script("power-menu")]) }}/>
            </box>
          </box>
          <label label={error} visible={error(Boolean)} wrap cssClasses={["feedback"]}/>
        </box>
      </Gtk.ScrolledWindow>
    </box>
  </window> as Astal.Window

  const resize = () => {
    const height = panel.gdkmonitor?.get_geometry().height ?? 800
    scroller.maxContentHeight = Math.max(260, Math.min(760, height - 200))
  }
  const monitorSignal = panel.connect("notify::gdkmonitor", resize)
  const visibilitySignal = panel.connect("notify::visible", () => {
    if (!panel.visible) network.clear()
    else if (page() === "network") void network.scan()
  })
  resize()

  togglePanel = (requested, monitor) => {
    if (monitor) panel.gdkmonitor = monitor
    else {
      const name = hyprland.focusedMonitor?.name
      panel.gdkmonitor = app.monitors.find(item => item.connector === name) ?? app.monitors[0]
    }
    if (requested && requested !== page()) { selectPage(requested); panel.show() }
    else panel.visible = !panel.visible
  }
  onCleanup(() => {
    hyprland.disconnect(urgentSignal)
    hyprland.disconnect(focusSignal)
    hyprland.disconnect(workspaceSignal)
    panel.disconnect(monitorSignal)
    panel.disconnect(visibilitySignal)
    network.dispose()
    audio.dispose()
    media.dispose()
    notifications.dispose()
    awake.dispose()
    clockTimer.cancel()
    updateTimer.cancel()
    panel.destroy()
  })

  function Bar({ monitor }: { monitor: Gdk.Monitor }) {
    let window: Astal.Window
    onCleanup(() => window.destroy())
    return <window $={self => { window = self }} visible name={`bar-${monitor.connector}`} namespace="controlcenter-bar"
      application={app} gdkmonitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE} anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}>
      <centerbox cssClasses={["bar"]}>
        <box $type="start" spacing={0}>
          <box cssClasses={["workspaces"]} $={self => addWorkspaceScroll(self, run)}>
            <For each={createBinding(hyprland, "workspaces")(workspaces =>
              [...workspaces].filter(workspace => workspace.id > 0).sort((left, right) => left.id - right.id))}>
              {(workspace: Hyprland.Workspace) => <button
                label={createBinding(workspace, "name")(name => name.replace(/[\r\n]/g, " "))}
                tooltipText={createBinding(workspace, "name")(name => `Workspace ${name}. Double-click to edit its note.`)}
                cssClasses={createComputed(() => ["workspace",
                  ...(focusedWorkspace()?.id === workspace.id ? ["active"] : []),
                  ...(urgentWorkspaces().includes(workspace.id) ? ["urgent"] : []),
                ])}
                $={self => addClickActions(self, {
                  primary: () => void run([script("workspace-notes"), "click", String(workspace.id)]),
                  middle: () => void run([script("workspace-notes"), "menu"]),
                  secondary: () => void run([script("workspace-notes"), "annotate", String(workspace.id)]),
                })}/>}
            </For>
          </box>
          <label label={createBinding(hyprland, "focusedClient")(client => client?.title ? ` ${client.title}` : "")}
            ellipsize={Pango.EllipsizeMode.END} maxWidthChars={30} cssClasses={["window-title"]}/>
        </box>
        <button $type="center" label={clock} cssClasses={["bar-module", "clock"]}
          tooltipText="Left click: Open calendar\nRight click: Show date"
          $={self => addClickActions(self, {
            primary: () => void run([script("open-calendar")]),
            secondary: () => {
              const alternate = !clockAlternate()
              setClockAlternate(alternate)
              refreshClock(alternate)
            },
          })}/>
        <box $type="end" spacing={0}>
          <button label={battery(value => value.text)} tooltipText={battery(value => value.tooltip)}
            cssClasses={battery(value => ["bar-module", "battery", value.class])}
            $={self => addClickActions(self, { primary: () => togglePanel("desktop", monitor) })}/>
          <button label={networkSummary(networkLabel)}
            tooltipText={networkSummary(value => `${value}\nLeft click: Network panel\nRight click: Login page\nMiddle click: Reconnect Wi-Fi`)}
            cssClasses={networkSummary(value => ["bar-module", "network", ...(value.startsWith("Ethernet: ") || value.match(/(\d+)%$/) ? [] : ["disconnected"])])}
            $={self => addClickActions(self, {
              primary: () => togglePanel("network", monitor),
              middle: () => void run([script("wifi-heal"), "--force"]),
              secondary: () => void run([script("wifi-portal"), "open"]),
            })}/>
          <button label={bluetooth(value => value.text)} tooltipText={bluetooth(value => value.tooltip)}
            cssClasses={bluetooth(value => ["bar-module", "bluetooth", value.class])}
            $={self => addClickActions(self, { primary: () => void run(["blueman-manager"]) })}/>
          <button label={audio.summary(audioLabel)} tooltipText="Audio devices, microphone and media"
            cssClasses={audio.summary(value => ["bar-module", "audio", ...(value === "MUTE" ? ["muted"] : [])])}
            $={self => addClickActions(self, { primary: () => togglePanel("sound", monitor) })}/>
          <button label={system(value => value.text)} tooltipText={system(value => value.tooltip)}
            cssClasses={system(value => ["bar-module", "system-stats", value.class])}
            $={self => addClickActions(self, {
              primary: () => void run(["kitty", "-e", "htop"]),
              secondary: () => void run(["kitty", "-e", "ncdu", "/home"]),
            })}/>
          <button visible={updates(value => value.class !== "none")} label={updates(value => value.text)} tooltipText={updates(value => value.tooltip)}
            cssClasses={updates(value => ["bar-module", "updates", value.class])}
            onClicked={() => void installUpdates()}/>
          <TrayItems/>
          <button label="" tooltipText="Left click: Sleep / Reboot / Shutdown\nRight click: Control center" cssClasses={["bar-module", "power"]}
            $={self => addClickActions(self, {
              primary: () => void run([script("power-menu")]),
              secondary: () => togglePanel("desktop", monitor),
            })}/>
        </box>
      </centerbox>
    </window>
  }

  const windows = <For each={createBinding(app, "monitors")}>
    {(monitor: Gdk.Monitor) => <This this={app}><Bar monitor={monitor}/></This>}
  </For>
  ready = true
  return windows
}

app.start({
  instanceName: "controlcenter",
  gtkTheme: "Adwaita",
  css,
  main: desktop,
  requestHandler(argv, reply) {
    if (argv[0] === "ping") {
      const mapped = app.monitors.length > 0 && app.monitors.every(monitor => app.get_window(`bar-${monitor.connector}`)?.get_mapped())
      reply(ready && mapped ? "ready" : "starting")
      return
    }
    if (argv[0] === "toggle" && ready) {
      const page = argv[1] === "system" ? "desktop" : argv[1]
      togglePanel(page === "network" || page === "appearance" || page === "sound" || page === "desktop" || page === "notifications" ? page : undefined)
      reply("ok")
      return
    }
    reply("Usage: ping | toggle [network|sound|desktop|appearance|notifications]")
  },
})
