import { For, createState, type Accessor } from "ags"
import { execAsync } from "ags/process"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"

const DND_MODE = "do-not-disturb"
const REFRESH_INTERVAL_MS = 2000

export type NotificationEntry = {
  id: number
  appName: string
  summary: string
  body: string
  source: "active" | "history"
}

export interface NotificationsController {
  entries: Accessor<NotificationEntry[]>
  count: Accessor<number>
  dnd: Accessor<boolean>
  status: Accessor<string>
  refresh(): Promise<void>
  setDnd(enabled: boolean): Promise<void>
  dispose(): void
}

function parseEntries(output: string, source: NotificationEntry["source"]): NotificationEntry[] {
  const value: unknown = JSON.parse(output)
  if (!Array.isArray(value)) throw new Error("Mako returned an invalid notification list")

  return value.flatMap(item => {
    if (!item || typeof item !== "object") return []
    const record = item as Record<string, unknown>
    if (typeof record.id !== "number") return []
    return [{
      id: record.id,
      appName: typeof record.app_name === "string" ? record.app_name : "Notification",
      summary: typeof record.summary === "string" ? record.summary : "",
      body: typeof record.body === "string" ? record.body : "",
      source,
    }]
  })
}

function mergeEntries(active: NotificationEntry[], history: NotificationEntry[]): NotificationEntry[] {
  const seen = new Set<number>()
  return [...active, ...history].filter(entry => {
    if (seen.has(entry.id)) return false
    seen.add(entry.id)
    return true
  })
}

export function createNotifications(
  refreshInterval = REFRESH_INTERVAL_MS,
  run: (argv: string[]) => Promise<string> = execAsync,
): NotificationsController {
  const [entries, setEntries] = createState<NotificationEntry[]>([])
  const [count, setCount] = createState(0)
  const [dnd, setDndState] = createState(false)
  const [status, setStatus] = createState("")
  let disposed = false
  let changingDnd = false
  let version = 0

  async function refresh() {
    if (disposed) return
    const requestVersion = ++version
    try {
      const [activeOutput, historyOutput, modesOutput] = await Promise.all([
        run(["makoctl", "list", "-j"]),
        run(["makoctl", "history", "-j"]),
        run(["makoctl", "mode"]),
      ])
      if (disposed || requestVersion !== version) return
      const current = mergeEntries(
        parseEntries(activeOutput, "active"),
        parseEntries(historyOutput, "history"),
      ).slice(0, 50)
      setEntries(current)
      setCount(current.length)
      setDndState(modesOutput.split(/\r?\n/).includes(DND_MODE))
      setStatus("")
    } catch {
      if (!disposed && requestVersion === version) setStatus("Could not read notifications from Mako.")
    }
  }

  async function setDnd(enabled: boolean) {
    if (disposed || changingDnd || enabled === dnd()) return
    changingDnd = true
    version += 1
    try {
      await run(["makoctl", "mode", enabled ? "-a" : "-r", DND_MODE])
      version += 1
      if (!disposed) {
        setDndState(enabled)
        setStatus("")
        await refresh()
      }
    } catch {
      version += 1
      if (!disposed) setStatus("Could not change Mako's do-not-disturb mode.")
    } finally {
      changingDnd = false
    }
  }

  const refreshSource = refreshInterval > 0
    ? GLib.timeout_add(GLib.PRIORITY_DEFAULT, refreshInterval, () => {
        void refresh()
        return GLib.SOURCE_CONTINUE
      })
    : 0
  if (refreshInterval > 0) void refresh()

  return {
    entries,
    count,
    dnd,
    status,
    refresh,
    setDnd,
    dispose() {
      disposed = true
      if (refreshSource) GLib.source_remove(refreshSource)
    },
  }
}

export function NotificationsPanel({ notifications }: { notifications: NotificationsController }) {
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={12} cssClasses={["page", "notifications-page"]}>
    <box spacing={8}>
      <label label="RECENT" xalign={0} hexpand cssClasses={["section-title"]}/>
      <button
        label={notifications.dnd(value => value ? "DND on" : "DND off")}
        cssClasses={notifications.dnd(value => value ? ["active"] : [])}
        onClicked={() => void notifications.setDnd(!notifications.dnd())}/>
      <button label="Refresh" onClicked={() => void notifications.refresh()}/>
    </box>

    <box orientation={Gtk.Orientation.VERTICAL} spacing={6}>
      <label
        visible={notifications.count(value => value === 0)}
        label="No current or recent notifications."
        xalign={0}
        cssClasses={["hint"]}/>
      <For each={notifications.entries}>
        {(entry: NotificationEntry) => <box orientation={Gtk.Orientation.VERTICAL} spacing={2} cssClasses={["notification-card"]}>
          <box spacing={8}>
            <label
              label={entry.appName || "Notification"}
              xalign={0}
              hexpand
              maxWidthChars={28}
              ellipsize={Pango.EllipsizeMode.END}
              cssClasses={["section-title"]}/>
            <label label={entry.source === "active" ? "CURRENT" : "HISTORY"} cssClasses={["hint"]}/>
          </box>
          <label
            label={entry.summary}
            visible={Boolean(entry.summary)}
            xalign={0}
            maxWidthChars={46}
            ellipsize={Pango.EllipsizeMode.END}/>
          <label
            label={entry.body}
            visible={Boolean(entry.body)}
            xalign={0}
            maxWidthChars={46}
            lines={3}
            wrap
            wrapMode={Pango.WrapMode.WORD_CHAR}
            ellipsize={Pango.EllipsizeMode.END}
            cssClasses={["hint"]}/>
        </box>}
      </For>
    </box>

    <label visible={notifications.status(Boolean)} label={notifications.status} wrap xalign={0} cssClasses={["feedback"]}/>
  </box>
}
