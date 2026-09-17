// Production-controller integration test. Run the bundle under dbus-run-session.
// It reads the live PipeWire graph without changing it and exports a private MPRIS fixture.

import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import { createAudio } from "../Audio"
import { createMedia } from "../Media"

const BUS_NAME = "org.mpris.MediaPlayer2.ControlcenterTest"
const OBJECT_PATH = "/org/mpris/MediaPlayer2"
const ROOT_XML = `
<node>
  <interface name="org.mpris.MediaPlayer2">
    <property name="Identity" type="s" access="read"/>
  </interface>
</node>`
const PLAYER_XML = `
<node>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="PlayPause"/>
    <method name="Next"/>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="Position" type="x" access="read"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="CanControl" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
  </interface>
</node>`

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message)
}

const calls: string[] = []
const service = {
  Identity: "Controlcenter test player",
  PlaybackStatus: "Paused",
  Position: 0,
  Metadata: {
    "mpris:trackid": new GLib.Variant("o", "/controlcenter/test/track"),
    "xesam:title": new GLib.Variant("s", "Fixture track"),
    "xesam:artist": new GLib.Variant("as", ["Fixture artist"]),
  },
  CanControl: true,
  CanPlay: true,
  CanPause: true,
  CanGoNext: true,
  PlayPause() {
    calls.push("play-pause")
  },
  Next() {
    calls.push("next")
  },
}

const connection = Gio.DBus.session
const request = connection.call_sync(
  "org.freedesktop.DBus",
  "/org/freedesktop/DBus",
  "org.freedesktop.DBus",
  "RequestName",
  new GLib.Variant("(su)", [BUS_NAME, 0]),
  new GLib.VariantType("(u)"),
  Gio.DBusCallFlags.NONE,
  -1,
  null,
)
const [requestResult] = request.deepUnpack() as [number]
assert(requestResult === 1, "The private MPRIS fixture could not own its bus name")

const rootObject = Gio.DBusExportedObject.wrapJSObject(ROOT_XML, service)
const playerObject = Gio.DBusExportedObject.wrapJSObject(PLAYER_XML, service)
rootObject.export(connection, OBJECT_PATH)
playerObject.export(connection, OBJECT_PATH)

const audio = createAudio()
const media = createMedia()
const loop = new GLib.MainLoop(null, false)
let requestedActions = false
let failure = "Timed out waiting for the real sound controllers"
const timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
  const audioReady = audio.outputs().length > 0 && audio.inputs().length > 0
    && audio.outputId() !== null && audio.inputId() !== null
  const mediaReady = media.selectedId() === BUS_NAME
    && media.title() === "Fixture track" && media.artist() === "Fixture artist"
  if (audioReady && mediaReady && !requestedActions) {
    requestedActions = true
    media.playPause()
    media.next()
  }
  if (audioReady && mediaReady && calls.join(",") === "play-pause,next") {
    failure = ""
    loop.quit()
    return GLib.SOURCE_REMOVE
  }
  return GLib.SOURCE_CONTINUE
})
const deadlineId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 8, () => {
  loop.quit()
  return GLib.SOURCE_REMOVE
})

try {
  loop.run()
  assert(!failure, failure)
  print(`ags-sound-services: PASS (${audio.outputs().length} outputs, ${audio.inputs().length} inputs, private MPRIS actions received)`)
} finally {
  if (GLib.MainContext.default().find_source_by_id(timeoutId)) GLib.source_remove(timeoutId)
  if (GLib.MainContext.default().find_source_by_id(deadlineId)) GLib.source_remove(deadlineId)
  audio.dispose()
  media.dispose()
  playerObject.unexport()
  rootObject.unexport()
  connection.call_sync(
    "org.freedesktop.DBus",
    "/org/freedesktop/DBus",
    "org.freedesktop.DBus",
    "ReleaseName",
    new GLib.Variant("(s)", [BUS_NAME]),
    new GLib.VariantType("(u)"),
    Gio.DBusCallFlags.NONE,
    -1,
    null,
  )
}
