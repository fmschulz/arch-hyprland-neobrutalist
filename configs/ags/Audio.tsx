import { For, createState, type Accessor } from "ags"
import AstalWp from "gi://AstalWp?version=0.1"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"

export type AudioEndpoint = {
  id: number
  label: string
  iconName: string
}

export interface AudioController {
  summary: Accessor<string>
  outputs: Accessor<AudioEndpoint[]>
  inputs: Accessor<AudioEndpoint[]>
  outputId: Accessor<number | null>
  inputId: Accessor<number | null>
  outputVolume: Accessor<number>
  microphoneMuted: Accessor<boolean>
  selectOutput(id: number): void
  selectInput(id: number): void
  setOutputVolume(value: number): void
  toggleOutputMute(): void
  toggleMicrophoneMute(): void
  dispose(): void
}

function endpointLabel(endpoint: AstalWp.Endpoint): string {
  const description = endpoint.description?.trim()
  const name = endpoint.name?.trim()
  if (description && name && description !== name) return `${description} · ${name}`
  return description || name || `Audio device ${endpoint.id}`
}

function endpointView(endpoint: AstalWp.Endpoint): AudioEndpoint {
  return {
    id: endpoint.id,
    label: endpointLabel(endpoint),
    iconName: endpoint.icon || "audio-card-symbolic",
  }
}

export function createAudio(): AudioController {
  const wp = AstalWp.get_default()
  const audio = wp.audio
  const [summary, setSummary] = createState("AUDIO")
  const [outputs, setOutputs] = createState<AudioEndpoint[]>([])
  const [inputs, setInputs] = createState<AudioEndpoint[]>([])
  const [outputId, setOutputId] = createState<number | null>(null)
  const [inputId, setInputId] = createState<number | null>(null)
  const [outputVolume, setOutputVolumeState] = createState(0)
  const [microphoneMuted, setMicrophoneMuted] = createState(false)
  let endpointSignals: Array<[AstalWp.Endpoint, number]> = []
  let defaultSignals: Array<[AstalWp.Endpoint, number]> = []

  function syncDefaults() {
    const speaker = audio.defaultSpeaker
    const microphone = audio.defaultMicrophone
    const volume = speaker.volume
    const hasOutput = (audio.speakers?.length ?? 0) > 0
    setOutputVolumeState(hasOutput ? volume : 0)
    setMicrophoneMuted((audio.microphones?.length ?? 0) > 0 && microphone.mute)
    setSummary(hasOutput ? (speaker.mute ? "MUTE" : `${Math.round(volume * 100)}%`) : "AUDIO")
  }

  function syncSelections() {
    const speakers = audio.speakers ?? []
    const microphones = audio.microphones ?? []
    const speaker = speakers.find(endpoint => endpoint.isDefault)
    const microphone = microphones.find(endpoint => endpoint.isDefault)
    const defaultSpeakerId = audio.defaultSpeaker.id
    const defaultMicrophoneId = audio.defaultMicrophone.id
    setOutputId(speaker?.id ?? (speakers.some(endpoint => endpoint.id === defaultSpeakerId) ? defaultSpeakerId : null))
    setInputId(microphone?.id ?? (microphones.some(endpoint => endpoint.id === defaultMicrophoneId) ? defaultMicrophoneId : null))
  }

  function watchDefaultNodes() {
    for (const [endpoint, id] of defaultSignals) endpoint.disconnect(id)
    const speaker = audio.defaultSpeaker
    const microphone = audio.defaultMicrophone
    defaultSignals = [
      [speaker, speaker.connect("notify::volume", syncDefaults)],
      [speaker, speaker.connect("notify::mute", syncDefaults)],
      [microphone, microphone.connect("notify::mute", syncDefaults)],
    ]
    syncDefaults()
  }

  function refreshEndpoints() {
    for (const [endpoint, id] of endpointSignals) endpoint.disconnect(id)
    const speakers = audio.speakers ?? []
    const microphones = audio.microphones ?? []
    setOutputs(speakers.map(endpointView))
    setInputs(microphones.map(endpointView))
    endpointSignals = [...speakers, ...microphones].map(endpoint => [
      endpoint,
      endpoint.connect("notify::is-default", syncSelections),
    ])
    syncSelections()
    syncDefaults()
  }

  const wpSignals = [wp.connect("ready", () => {
    refreshEndpoints()
    watchDefaultNodes()
  })]
  const audioSignals = [
    audio.connect("speaker-added", refreshEndpoints),
    audio.connect("speaker-removed", refreshEndpoints),
    audio.connect("microphone-added", refreshEndpoints),
    audio.connect("microphone-removed", refreshEndpoints),
    audio.connect("notify::default-speaker", watchDefaultNodes),
    audio.connect("notify::default-microphone", watchDefaultNodes),
  ]
  refreshEndpoints()
  watchDefaultNodes()

  return {
    summary,
    outputs,
    inputs,
    outputId,
    inputId,
    outputVolume,
    microphoneMuted,
    selectOutput(id) {
      audio.get_speaker(id)?.set_is_default(true)
    },
    selectInput(id) {
      audio.get_microphone(id)?.set_is_default(true)
    },
    setOutputVolume(value) {
      audio.defaultSpeaker.set_volume(Math.max(0, Math.min(1.5, value)))
    },
    toggleOutputMute() {
      const speaker = audio.defaultSpeaker
      speaker.set_mute(!speaker.mute)
    },
    toggleMicrophoneMute() {
      const microphone = audio.defaultMicrophone
      microphone.set_mute(!microphone.mute)
    },
    dispose() {
      for (const id of wpSignals) wp.disconnect(id)
      for (const id of audioSignals) audio.disconnect(id)
      for (const [endpoint, id] of endpointSignals) endpoint.disconnect(id)
      for (const [endpoint, id] of defaultSignals) endpoint.disconnect(id)
    },
  }
}

function DeviceMenu({
  kind,
  devices,
  selectedId,
  select,
}: {
  kind: "output" | "input"
  devices: Accessor<AudioEndpoint[]>
  selectedId: Accessor<number | null>
  select(id: number): void
}) {
  let popover!: Gtk.Popover
  const selectedLabel = selectedId(id => devices().find(device => device.id === id)?.label ?? `No ${kind} device`)
  return <menubutton hexpand tooltipText={selectedLabel} sensitive={devices(value => value.length > 0)}>
    <box spacing={8}>
      <label label={selectedLabel} xalign={0} hexpand maxWidthChars={36} ellipsize={Pango.EllipsizeMode.END}/>
      <image iconName="pan-down-symbolic"/>
    </box>
    <popover $={self => { popover = self }}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <For each={devices}>
          {(device: AudioEndpoint) => <button
            tooltipText={`Select ${kind}: ${device.label}`}
            cssClasses={selectedId(id => id === device.id ? ["chosen"] : [])}
            onClicked={() => {
              select(device.id)
              popover.popdown()
            }}>
            <box spacing={8}>
              <image iconName={device.iconName}/>
              <label label={device.label} xalign={0} maxWidthChars={40} ellipsize={Pango.EllipsizeMode.END}/>
            </box>
          </button>}
        </For>
      </box>
    </popover>
  </menubutton>
}

export function AudioPanel({ audio }: { audio: AudioController }) {
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={10} cssClasses={["audio-page", "widget-card"]}>
    <label label="AUDIO OUTPUT" xalign={0} cssClasses={["section-title"]}/>
    <DeviceMenu kind="output" devices={audio.outputs} selectedId={audio.outputId} select={id => audio.selectOutput(id)}/>
    <box spacing={8} homogeneous>
      <button sensitive={audio.outputId(id => id !== null)} label="−" tooltipText="Volume down" onClicked={() => audio.setOutputVolume(audio.outputVolume() - 0.05)}/>
      <button sensitive={audio.outputId(id => id !== null)} label={audio.summary} tooltipText="Toggle output mute" onClicked={() => audio.toggleOutputMute()}/>
      <button sensitive={audio.outputId(id => id !== null)} label="+" tooltipText="Volume up" onClicked={() => audio.setOutputVolume(audio.outputVolume() + 0.05)}/>
    </box>
    <label label="MICROPHONE" xalign={0} cssClasses={["section-title"]}/>
    <DeviceMenu kind="input" devices={audio.inputs} selectedId={audio.inputId} select={id => audio.selectInput(id)}/>
    <button
      sensitive={audio.inputId(id => id !== null)}
      label={audio.microphoneMuted(muted => muted ? "Unmute microphone" : "Mute microphone")}
      cssClasses={audio.microphoneMuted(muted => muted ? ["active"] : [])}
      onClicked={() => audio.toggleMicrophoneMute()}/>
  </box>
}
