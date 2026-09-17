import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { execFileSync } from "node:child_process"
import vm from "node:vm"
import ts from "typescript"

// Exercise the app's actual functions without starting GTK or changing hardware.
const app = readFileSync(new URL("../app.tsx", import.meta.url), "utf8")
const code = ts.transpile(app.slice(app.indexOf("function read("), app.indexOf("function networkLabel(")))
function status(devices) {
  const names = Object.keys(devices)[Symbol.iterator]()
  return vm.runInNewContext(`${code}\nbatteryStatus()`, {
    TextDecoder,
    Gio: {
      FileQueryInfoFlags: { NONE: 0 },
      File: { new_for_path: () => ({ enumerate_children: () => ({
        next_file: () => { const next = names.next(); return next.done ? null : { get_name: () => next.value } },
        close: () => {},
      }) }) },
    },
    GLib: { file_get_contents: path => {
      const [, name, field] = path.match(/^\/sys\/class\/power_supply\/([^/]+)\/(.+)$/)
      if (!(field in devices[name])) throw new Error("Missing optional sysfs field")
      return [true, new TextEncoder().encode(devices[name][field])]
    } },
  })
}

const ACAD = { type: "Mains", online: "1" }
const BAT1 = { type: "Battery", capacity: "100", status: "Not charging" }
const HID = { type: "Battery", scope: "Device", capacity: "0", status: "Unknown" }
for (const devices of [{ ACAD, BAT1, HID }, { HID, BAT1, ACAD }]) {
  const result = status(devices)
  assert.match(result.text, /100%$/)
  assert.equal(result.class, "normal")
  assert.match(result.tooltip, /Fully charged\nAC power connected$/)
}
assert.match(status({ HID }).tooltip, /No battery detected/)
const limited = status({ ACAD, BAT1: { ...BAT1, capacity: "80" }, HID })
assert.match(limited.tooltip, /Status: Not charging\nAC power connected$/)
const charging = status({ BAT1: { ...BAT1, capacity: "50", status: "Charging" }, ACAD, HID })
assert.equal(charging.class, "charging")
assert.match(charging.tooltip, /Status: Charging\nAC power connected\nTime estimate unavailable$/)
const low = status({ BAT1: { ...BAT1, capacity: "12", status: "Discharging" }, HID })
assert.equal(low.class, "critical")
assert.match(low.tooltip, /On battery power/)
console.log("battery-contract: PASS (peripheral exclusion, enumeration order, full, limited, charging, low)")

if (process.argv.includes("--live")) {
  const actual = JSON.parse(execFileSync("gjs", ["-c", `const Gio=imports.gi.Gio; const GLib=imports.gi.GLib; ${code}\nprint(JSON.stringify(batteryStatus()))`], { encoding: "utf8" }))
  const capacity = readFileSync("/sys/class/power_supply/BAT1/capacity", "utf8").trim()
  assert.ok(actual.text.endsWith(`${capacity}%`))
  console.log(`battery-live: PASS (matches BAT1)\n${actual.tooltip}`)
}
