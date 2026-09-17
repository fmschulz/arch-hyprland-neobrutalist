// Fake-controller UI test. It does not touch the live audio or media session.
// From this directory, bundle with:
// ags bundle --gtk 4 tests/ags-sound.tsx ../../../tasks/ags-sound-test.js

import { createState } from "ags"
import app from "ags/gtk4/app"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import { AudioPanel, type AudioController, type AudioEndpoint } from "../Audio"
import { MediaPanel, type MediaController, type MediaPlayerOption } from "../Media"

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

function descendants(root: Gtk.Widget): Gtk.Widget[] {
  const found: Gtk.Widget[] = []
  for (let child = root.get_first_child(); child; child = child.get_next_sibling()) {
    found.push(child, ...descendants(child))
  }
  return found
}

function menuButtons(menu: Gtk.MenuButton): Gtk.Button[] {
  const popover = menu.get_popover()
  assert(popover !== null, "A selector has no popover")
  return descendants(popover).filter(widget => widget instanceof Gtk.Button) as Gtk.Button[]
}

function fakeAudio(): { controller: AudioController; actions: string[]; removeDevices(): void } {
  const outputDevices: AudioEndpoint[] = [
    { id: 1, label: "Laptop speakers with a deliberately long endpoint name", iconName: "audio-speakers-symbolic" },
    { id: 2, label: "Dock audio", iconName: "audio-card-symbolic" },
  ]
  const inputDevices: AudioEndpoint[] = [
    { id: 3, label: "Laptop microphone", iconName: "audio-input-microphone-symbolic" },
    { id: 4, label: "Webcam microphone", iconName: "audio-input-microphone-symbolic" },
  ]
  const [summary, setSummary] = createState("50%")
  const [outputs, setOutputs] = createState(outputDevices)
  const [inputs, setInputs] = createState(inputDevices)
  const [outputId, setOutputId] = createState<number | null>(1)
  const [inputId, setInputId] = createState<number | null>(3)
  const [outputVolume, setOutputVolume] = createState(0.5)
  const [outputMuted, setOutputMuted] = createState(false)
  const [microphoneMuted, setMicrophoneMuted] = createState(false)
  const actions: string[] = []
  const controller: AudioController = {
    summary,
    outputs,
    inputs,
    outputId,
    inputId,
    outputVolume,
    microphoneMuted,
    selectOutput(id) {
      actions.push(`output:${id}`)
      setOutputId(id)
    },
    selectInput(id) {
      actions.push(`input:${id}`)
      setInputId(id)
    },
    setOutputVolume(value) {
      actions.push(`volume:${value.toFixed(2)}`)
      setOutputVolume(value)
      setSummary(`${Math.round(value * 100)}%`)
    },
    toggleOutputMute() {
      const muted = !outputMuted()
      actions.push("output-mute")
      setOutputMuted(muted)
      setSummary(muted ? "MUTE" : `${Math.round(outputVolume() * 100)}%`)
    },
    toggleMicrophoneMute() {
      actions.push("microphone-mute")
      setMicrophoneMuted(!microphoneMuted())
    },
    dispose() {},
  }
  return {
    controller,
    actions,
    removeDevices() {
      setOutputs([])
      setInputs([])
      setOutputId(null)
      setInputId(null)
      setSummary("AUDIO")
    },
  }
}

function fakeMedia(): { controller: MediaController; actions: string[] } {
  const options: MediaPlayerOption[] = [
    { id: "one", name: "First player" },
    { id: "two", name: "Second player with a deliberately long identity" },
  ]
  const [players] = createState(options)
  const [selectedId, setSelectedId] = createState<string | null>("one")
  const [title, setTitle] = createState("First track")
  const [artist, setArtist] = createState("First artist")
  const [playing, setPlaying] = createState(false)
  const [canToggle] = createState(true)
  const [canNext] = createState(true)
  const actions: string[] = []
  const controller: MediaController = {
    players,
    selectedId,
    title,
    artist,
    playing,
    canToggle,
    canNext,
    selectPlayer(id) {
      actions.push(`player:${id}`)
      setSelectedId(id)
      setTitle(id === "two" ? "Second track" : "First track")
      setArtist(id === "two" ? "Second artist" : "First artist")
    },
    playPause() {
      actions.push("play-pause")
      setPlaying(!playing())
    },
    next() {
      actions.push("next")
      setTitle("Next track")
    },
    dispose() {},
  }
  return { controller, actions }
}

async function run(window: Gtk.Window, audio: ReturnType<typeof fakeAudio>, media: ReturnType<typeof fakeMedia>) {
  await nextTurn()
  const widgets = descendants(window)
  const selectors = widgets.filter(widget => widget instanceof Gtk.MenuButton) as Gtk.MenuButton[]
  const buttons = widgets.filter(widget => widget instanceof Gtk.Button) as Gtk.Button[]
  assert(selectors.length === 3, "Output, input, and player selectors did not render")

  const outputOptions = menuButtons(selectors[0])
  const inputOptions = menuButtons(selectors[1])
  const playerOptions = menuButtons(selectors[2])
  assert(outputOptions.length === 2 && inputOptions.length === 2 && playerOptions.length === 2, "Selector options did not render")
  outputOptions[1].emit("clicked")
  inputOptions[1].emit("clicked")

  const volumeUp = buttons.find(button => button.get_tooltip_text() === "Volume up")
  const outputMute = buttons.find(button => button.get_tooltip_text() === "Toggle output mute")
  const microphoneMute = buttons.find(button => button.get_label() === "Mute microphone")
  assert(volumeUp !== undefined && outputMute !== undefined && microphoneMute !== undefined, "Audio action buttons did not render")
  volumeUp.emit("clicked")
  outputMute.emit("clicked")
  microphoneMute.emit("clicked")

  playerOptions[1].emit("clicked")
  await nextTurn()
  const playPause = buttons.find(button => button.get_tooltip_text() === "Play or pause")
  const next = buttons.find(button => button.get_tooltip_text() === "Next track")
  assert(playPause !== undefined && next !== undefined, "Media action buttons did not render")
  playPause.emit("clicked")
  next.emit("clicked")
  await nextTurn()

  assert(audio.controller.outputId() === 2 && audio.controller.inputId() === 4, "Device selection did not update the controller")
  assert(audio.controller.outputVolume() === 0.55, "Volume adjustment did not update the controller")
  assert(audio.controller.summary() === "MUTE" && audio.controller.microphoneMuted(), "Mute controls did not update the controller")
  assert(media.controller.selectedId() === "two" && media.controller.playing(), "Player selection or play/pause did not update the controller")
  assert(media.controller.title() === "Next track", "Next did not update the selected track")
  assert(audio.actions.join(",") === "output:2,input:4,volume:0.55,output-mute,microphone-mute", "Unexpected audio actions")
  assert(media.actions.join(",") === "player:two,play-pause,next", "Unexpected media actions")

  audio.removeDevices()
  await nextTurn()
  assert(!selectors[0].get_sensitive() && !selectors[1].get_sensitive(), "Empty audio selectors remained enabled")
  assert(!volumeUp.get_sensitive() && !outputMute.get_sensitive() && !microphoneMute.get_sensitive(), "Empty audio actions remained enabled")
  assert(audio.controller.summary() === "AUDIO", "Empty audio state retained a stale volume")
  print("ags-sound: PASS")
  window.close()
  app.quit()
}

app.start({
  instanceName: "ags-sound-test",
  main() {
    const audio = fakeAudio()
    const media = fakeMedia()
    const window = <Gtk.Window application={app} visible title="AGS sound test" defaultWidth={460}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={14}>
        <AudioPanel audio={audio.controller}/>
        <MediaPanel media={media.controller}/>
      </box>
    </Gtk.Window>
    void run(window as Gtk.Window, audio, media).catch(error => {
      printerr(`ags-sound: FAIL: ${error instanceof Error ? error.message : String(error)}`)
      app.quit(1)
    })
  },
})
