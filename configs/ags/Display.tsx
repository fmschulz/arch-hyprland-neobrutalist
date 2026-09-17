import { createComputed, createState } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import { script } from "./Appearance"

interface DisplayState { phase: string; message: string; deadline: number }
interface Monitor { name: string; disabled: boolean; mirrorOf: string; width: number; height: number }

export function createDisplay() {
  const [busy, setBusy] = createState(false)
  const [error, setError] = createState("")
  const state = createPoll<DisplayState>({ phase: "idle", message: "", deadline: 0 }, 1000, async previous => {
    try { return JSON.parse(await execAsync([script("display-profile"), "status"])) as DisplayState }
    catch { return previous }
  })
  const monitors = createPoll<Monitor[]>([], 3000, async () => {
    try { return JSON.parse(await execAsync(["hyprctl", "-j", "monitors", "all"])) as Monitor[] }
    catch { return [] }
  })
  const lidClosed = createPoll(false, 1000, () => {
    try { return new TextDecoder().decode(GLib.file_get_contents("/proc/acpi/button/lid/LID0/state")[1]).includes("closed") }
    catch { return false }
  })
  async function run(action: "preview" | "keep" | "revert", profile?: string) {
    if (busy()) return
    setBusy(true)
    setError("")
    try { await execAsync([script("display-profile"), action, ...(profile ? [profile] : [])]) }
    catch { setError("Display change did not complete. Check the display status before retrying.") }
    finally { setBusy(false) }
  }
  return { state, monitors, lidClosed, busy, error, run }
}

export function DisplayPanel({ display }: { display: ReturnType<typeof createDisplay> }) {
  const pending = display.state(state => state.phase === "preview" || state.phase === "starting")
  const seconds = createPoll(0, 1000, () => Math.max(0, display.state().deadline - Math.floor(Date.now() / 1000)))
  const hasExternal = (items: Monitor[]) => items.some(item => !/^(eDP|LVDS)-/.test(item.name))
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={8} cssClasses={["widget-card"]}>
    <label label="DISPLAYS" cssClasses={["section-title"]} xalign={0}/>
    <label label={display.monitors(monitors => monitors.filter(m => !m.disabled).map(m => `${m.name}  ${m.width}×${m.height}`).join("  ·  ") || "No display information")}
      wrap xalign={0} cssClasses={["hint"]}/>
    <box spacing={6} homogeneous sensitive={display.busy(value => !value)} visible={pending(value => !value)}>
      <button label="Laptop" sensitive={display.lidClosed(value => !value)} onClicked={() => void display.run("preview", "laptop")}/>
      <button label="External" sensitive={display.monitors(hasExternal)}
        onClicked={() => void display.run("preview", "external")}/>
      <button label="Mirror" sensitive={createComputed(() => !display.lidClosed() && hasExternal(display.monitors()))}
        onClicked={() => void display.run("preview", "mirror")}/>
    </box>
    <label visible={display.lidClosed} label="Open the lid to use Laptop or Mirror." xalign={0} wrap cssClasses={["hint"]}/>
    <box orientation={Gtk.Orientation.VERTICAL} spacing={8} visible={pending}>
      <label label={seconds(value => `Reverting in ${value}s unless you keep this layout.`)} wrap xalign={0}/>
      <box homogeneous spacing={8} sensitive={display.busy(value => !value)}>
        <button label="Revert" onClicked={() => void display.run("revert")}/>
        <button label="Keep layout" cssClasses={["active"]} onClicked={() => void display.run("keep")}/>
      </box>
    </box>
    <label label={display.state(state => state.message)} visible={createComputed(() => !pending() && !!display.state().message)} wrap xalign={0} cssClasses={["hint"]}/>
    <label label={display.error} visible={display.error(Boolean)} wrap xalign={0} cssClasses={["feedback"]}/>
    <label label="Session only. Display changes revert after 15 seconds unless kept." wrap xalign={0} cssClasses={["hint"]}/>
  </box>
}
