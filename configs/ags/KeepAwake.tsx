import { createState, type Accessor } from "ags"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"

const TICK_INTERVAL_MS = 1000

type InhibitorLease = {
  input: Gio.OutputStream
  finished: Promise<void>
}

export interface KeepAwakeController {
  active: Accessor<boolean>
  summary: Accessor<string>
  status: Accessor<string>
  start(seconds: number): Promise<void>
  cancel(): Promise<void>
  dispose(): void
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

function formatRemaining(seconds: number): string {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const remainder = seconds % 60
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`
    : `${minutes}:${String(remainder).padStart(2, "0")}`
}

export function createKeepAwake(
  who = "controlcenter-ags",
  inhibitCommand = "systemd-inhibit",
): KeepAwakeController {
  const [active, setActive] = createState(false)
  const [summary, setSummary] = createState("Off")
  const [status, setStatus] = createState("")
  let deadline = 0
  let disposed = false
  let generation = 0
  let lease: InhibitorLease | null = null
  let tickSource = 0

  function stopTimer() {
    if (tickSource) GLib.source_remove(tickSource)
    tickSource = 0
  }

  function updateCountdown(): boolean {
    const seconds = Math.max(0, Math.ceil((deadline - GLib.get_monotonic_time()) / GLib.USEC_PER_SEC))
    setSummary(seconds > 0 ? formatRemaining(seconds) : "Off")
    if (seconds > 0) return true

    tickSource = 0
    void cancel()
    return false
  }

  async function releaseCurrent() {
    const current = lease
    lease = null
    stopTimer()
    deadline = 0
    setSummary("Off")
    if (!current) {
      setActive(false)
      return
    }

    try {
      current.input.close(null)
      await current.finished
    } catch {
      if (!disposed) setStatus("The idle inhibitor did not stop cleanly.")
    }
    if (!lease) setActive(false)
  }

  async function start(seconds: number) {
    if (!Number.isFinite(seconds) || seconds <= 0) {
      setStatus("Choose a positive keep-awake duration.")
      return
    }
    const request = ++generation
    await releaseCurrent()
    if (disposed || request !== generation) return

    try {
      const process = Gio.Subprocess.new([
        inhibitCommand,
        "--what=idle",
        `--who=${who}`,
        "--why=Timed keep awake",
        "--mode=block",
        "sh",
        "-c",
        "read -r _ || exit 0",
      ], Gio.SubprocessFlags.STDIN_PIPE | Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE)
      const input = process.get_stdin_pipe()
      if (!input) throw new Error("systemd-inhibit has no input pipe")
      const current = { input, finished: waitForProcess(process) }
      lease = current
      deadline = GLib.get_monotonic_time() + Math.ceil(seconds) * GLib.USEC_PER_SEC
      setActive(true)
      setStatus("")
      updateCountdown()
      tickSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, TICK_INTERVAL_MS, () => updateCountdown()
        ? GLib.SOURCE_CONTINUE
        : GLib.SOURCE_REMOVE)
      void current.finished.catch(() => undefined).then(() => {
        if (lease !== current) return
        lease = null
        stopTimer()
        deadline = 0
        setActive(false)
        setSummary("Off")
        if (!disposed) setStatus("The idle inhibitor ended before its timer.")
      })
    } catch {
      if (!disposed) setStatus("Could not start the idle inhibitor.")
    }
  }

  async function cancel() {
    generation += 1
    await releaseCurrent()
  }

  return {
    active,
    summary,
    status,
    start,
    cancel,
    dispose() {
      disposed = true
      generation += 1
      stopTimer()
      deadline = 0
      setSummary("Off")
      setActive(false)
      const current = lease
      lease = null
      if (current) {
        try { current.input.close(null) } catch { /* Closing the app also closes the pipe. */ }
      }
    },
  }
}

export function KeepAwakePanel({ awake }: { awake: KeepAwakeController }) {
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={12} cssClasses={["widget-card", "keep-awake-card"]}>
    <box spacing={8}>
      <label label="Keep awake" xalign={0} hexpand cssClasses={["section-title"]}/>
      <label label={awake.summary} cssClasses={awake.active(value => value ? ["active"] : ["hint"])}/>
    </box>
    <label
      label="Pauses automatic dimming, lock and sleep; manual lock still works"
      xalign={0}
      wrap
      cssClasses={["hint"]}/>
    <box spacing={8} homogeneous>
      <button label="30 min" onClicked={() => void awake.start(30 * 60)}/>
      <button label="60 min" onClicked={() => void awake.start(60 * 60)}/>
      <button label="120 min" onClicked={() => void awake.start(120 * 60)}/>
    </box>
    <button label="Cancel keep awake" sensitive={awake.active} onClicked={() => void awake.cancel()}/>
    <label visible={awake.status(Boolean)} label={awake.status} wrap xalign={0} cssClasses={["feedback"]}/>
  </box>
}
