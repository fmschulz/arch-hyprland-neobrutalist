import app from "ags/gtk4/app"
import { execAsync } from "ags/process"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import { KeepAwakePanel, createKeepAwake, type KeepAwakeController } from "../KeepAwake"
import { NotificationsPanel, createNotifications, type NotificationsController } from "../Notifications"

const TEST_APP = "Control Center Service Test"
const TEST_WHO = "controlcenter-ags-fixture"

type MakoFixture = {
  process: Gio.Subprocess
  configDir: string
}

type InhibitorFixture = {
  command: string
  directory: string
  state: string
}

type MakoCommands = {
  run(argv: string[]): Promise<string>
  holdModeRead(): { captured: Promise<void>; release(): void }
}

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message)
}

function delay(milliseconds: number): Promise<void> {
  return new Promise(resolve => {
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, milliseconds, () => {
      resolve()
      return GLib.SOURCE_REMOVE
    })
  })
}

async function waitUntil(predicate: () => boolean | Promise<boolean>, message: string, timeout = 5000) {
  const deadline = GLib.get_monotonic_time() + timeout * 1000
  while (GLib.get_monotonic_time() < deadline) {
    if (await predicate()) return
    await delay(50)
  }
  throw new Error(message)
}

async function inhibitorPresent(command: string): Promise<boolean> {
  const output = await execAsync([command, "--list", "--json=short", "--no-pager"])
  const inhibitors: unknown = JSON.parse(output)
  return Array.isArray(inhibitors) && inhibitors.some(item =>
    !!item && typeof item === "object" && (item as Record<string, unknown>).who === TEST_WHO)
}

function startInhibitorFixture(): InhibitorFixture {
  const directory = GLib.dir_make_tmp("ags-inhibitor-test-XXXXXX")
  const command = `${directory}/systemd-inhibit`
  const state = `${directory}/state`
  const script = [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    'state="${0%/*}/state"',
    "if [[ ${1:-} == --list ]]; then",
    "  if [[ -f $state ]]; then",
    `    printf '[{"who":"${TEST_WHO}"}]\\n'`,
    "  else",
    "    printf '[]\\n'",
    "  fi",
    "  exit 0",
    "fi",
    ': >"$state"',
    'trap \'rm -f -- "$state"\' EXIT',
    "IFS= read -r _ || true",
    "",
  ].join("\n")
  assert(GLib.file_set_contents(command, script), "Could not write the inhibitor fixture")
  assert(GLib.chmod(command, 0o700) === 0, "Could not make the inhibitor fixture executable")
  return { command, directory, state }
}

function stopInhibitorFixture(fixture: InhibitorFixture) {
  GLib.unlink(fixture.command)
  GLib.unlink(fixture.state)
  GLib.rmdir(fixture.directory)
}

function makoCommands(): MakoCommands {
  let pending: { captured(): void; waiting: Promise<void> } | null = null
  return {
    async run(argv) {
      const output = await execAsync(argv)
      if (pending && argv.length === 2 && argv[0] === "makoctl" && argv[1] === "mode") {
        const current = pending
        pending = null
        current.captured()
        await current.waiting
      }
      return output
    },
    holdModeRead() {
      let markCaptured!: () => void
      let release!: () => void
      const captured = new Promise<void>(resolve => { markCaptured = resolve })
      const waiting = new Promise<void>(resolve => { release = resolve })
      pending = { captured: markCaptured, waiting }
      return { captured, release }
    },
  }
}

function waitForExit(process: Gio.Subprocess): Promise<void> {
  return new Promise((resolve, reject) => {
    process.wait_async(null, (_source, result) => {
      try {
        process.wait_finish(result)
        resolve()
      } catch (error) {
        reject(error)
      }
    })
  })
}

async function testNotifications(notifications: NotificationsController, commands: MakoCommands) {
  const token = `ags-service-${GLib.get_monotonic_time()}`
  await execAsync(["notify-send", "--app-name", TEST_APP, "--expire-time", "60000", token, "Synthetic fixture body"])
  await waitUntil(async () => {
    await notifications.refresh()
    return notifications.entries().some(entry => entry.summary === token && entry.source === "active")
  }, "The controlled notification did not reach Mako")

  const current = notifications.entries().find(entry => entry.summary === token)
  assert(!!current, "The controlled notification was missing")
  await execAsync(["makoctl", "dismiss", "-n", String(current.id)])
  await waitUntil(async () => {
    await notifications.refresh()
    return notifications.entries().some(entry => entry.summary === token && entry.source === "history")
  }, "The controlled notification did not move into Mako history")

  const heldMode = commands.holdModeRead()
  const staleRefresh = notifications.refresh()
  await heldMode.captured
  await notifications.setDnd(true)
  heldMode.release()
  await staleRefresh
  assert(notifications.dnd(), "Mako do-not-disturb mode did not activate")
  assert((await execAsync(["makoctl", "mode"])).split(/\r?\n/).includes("do-not-disturb"), "Mako did not report do-not-disturb mode")
  await notifications.setDnd(false)
  assert(!notifications.dnd(), "Mako do-not-disturb mode did not deactivate")

  const olderMode = commands.holdModeRead()
  const olderRefresh = notifications.refresh()
  await olderMode.captured
  await execAsync(["makoctl", "mode", "-a", "do-not-disturb"])
  await notifications.refresh()
  olderMode.release()
  await olderRefresh
  assert(notifications.dnd(), "An older refresh overwrote the newer Mako mode")
  await notifications.setDnd(false)
  assert(!notifications.status(), "The notification controller reported an unexpected error")
}

async function testKeepAwake(awake: KeepAwakeController, inhibitCommand: string) {
  await awake.start(2)
  await waitUntil(() => inhibitorPresent(inhibitCommand), "The mock idle inhibitor did not start")
  assert(awake.active() && awake.summary() !== "Off", "The keep-awake countdown did not start")
  await waitUntil(async () => !await inhibitorPresent(inhibitCommand), "The timed mock idle inhibitor did not expire", 5000)
  await waitUntil(() => !awake.active(), "The controller stayed active after expiry")
  assert(awake.summary() === "Off", "The countdown label remained after expiry")

  await awake.start(30)
  await waitUntil(() => inhibitorPresent(inhibitCommand), "The cancellable mock idle inhibitor did not start")
  await awake.cancel()
  await waitUntil(async () => !await inhibitorPresent(inhibitCommand), "The cancelled mock idle inhibitor remained active")
  assert(!awake.active() && awake.summary() === "Off", "Cancel did not clear the countdown")
  assert(!awake.status(), "The keep-awake controller reported an unexpected error")

  await awake.start(30)
  await waitUntil(() => inhibitorPresent(inhibitCommand), "The disposable mock idle inhibitor did not start")
  awake.dispose()
  await waitUntil(async () => !await inhibitorPresent(inhibitCommand), "Disposing the controller left the mock inhibitor active")
  assert(!awake.active() && awake.summary() === "Off", "Dispose did not clear the countdown")
}

async function stopMako(process: Gio.Subprocess, configDir: string) {
  process.force_exit()
  await waitForExit(process).catch(() => undefined)
  GLib.unlink(`${configDir}/config`)
  GLib.rmdir(configDir)
}

async function notificationOwnerPid(): Promise<string | null> {
  const output = await execAsync([
    "busctl", "--user", "call",
    "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
    "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications",
  ])
  return output.trim().match(/^u\s+(\d+)$/)?.[1] ?? null
}

function startMako(): MakoFixture {
  const configDir = GLib.dir_make_tmp("ags-mako-test-XXXXXX")
  GLib.file_set_contents(`${configDir}/config`, `max-history=10
default-timeout=60000
width=400
height=100

[mode=do-not-disturb]
invisible=1
`)
  return {
    process: Gio.Subprocess.new(["mako", "--config", `${configDir}/config`], Gio.SubprocessFlags.NONE),
    configDir,
  }
}

async function run(
  window: Gtk.Window,
  notifications: NotificationsController,
  awake: KeepAwakeController,
  mako: MakoFixture,
  commands: MakoCommands,
  inhibitor: InhibitorFixture,
) {
  const testDisplay = GLib.getenv("AGS_TEST_DISPLAY")
  assert(!!testDisplay && GLib.getenv("WAYLAND_DISPLAY") === testDisplay, "Run this fixture on the verified nested Wayland display")
  assert(!!GLib.getenv("DBUS_SESSION_BUS_ADDRESS"), "Run this fixture inside a private dbus-run-session")

  try {
    await waitUntil(async () => {
      const owners = await execAsync(["busctl", "--user", "list", "--no-pager"])
      return owners.split(/\r?\n/).some(line => line.startsWith("org.freedesktop.Notifications "))
    }, "The isolated Mako service did not start")
    const childPid = mako.process.get_identifier()
    assert(!!childPid && await notificationOwnerPid() === childPid, "The test Mako process does not own the private notification bus")
    await testNotifications(notifications, commands)
    await testKeepAwake(awake, inhibitor.command)
    print("ags-desktop-services: PASS")
  } finally {
    notifications.dispose()
    awake.dispose()
    await stopMako(mako.process, mako.configDir)
    stopInhibitorFixture(inhibitor)
    window.close()
  }
}

app.start({
  instanceName: "ags-desktop-services-test",
  main() {
    const mako = startMako()
    const inhibitor = startInhibitorFixture()
    const commands = makoCommands()
    const notifications = createNotifications(0, commands.run)
    const awake = createKeepAwake(TEST_WHO, inhibitor.command)
    const window = <Gtk.Window application={app} visible title="AGS desktop services test">
      <box orientation={Gtk.Orientation.VERTICAL}>
        <NotificationsPanel notifications={notifications}/>
        <KeepAwakePanel awake={awake}/>
      </box>
    </Gtk.Window> as Gtk.Window
    void run(window, notifications, awake, mako, commands, inhibitor).then(
      () => app.quit(),
      error => {
        printerr(`ags-desktop-services: FAIL: ${error instanceof Error ? error.message : String(error)}`)
        app.quit(1)
      },
    )
    return window
  },
})
