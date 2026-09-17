import { For, createState, type Accessor } from "ags"
import AstalMpris from "gi://AstalMpris?version=0.1"
import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango?version=1.0"

export type MediaPlayerOption = {
  id: string
  name: string
}

export interface MediaController {
  players: Accessor<MediaPlayerOption[]>
  selectedId: Accessor<string | null>
  title: Accessor<string>
  artist: Accessor<string>
  playing: Accessor<boolean>
  canToggle: Accessor<boolean>
  canNext: Accessor<boolean>
  selectPlayer(id: string): void
  playPause(): void
  next(): void
  dispose(): void
}

function playerName(player: AstalMpris.Player): string {
  return player.identity || player.busName.replace(/^org\.mpris\.MediaPlayer2\./, "")
}

export function createMedia(): MediaController {
  const mpris = AstalMpris.get_default()
  const [players, setPlayers] = createState<MediaPlayerOption[]>([])
  const [selectedId, setSelectedId] = createState<string | null>(null)
  const [title, setTitle] = createState("")
  const [artist, setArtist] = createState("")
  const [playing, setPlaying] = createState(false)
  const [canToggle, setCanToggle] = createState(false)
  const [canNext, setCanNext] = createState(false)
  let tracked = new Map<string, AstalMpris.Player>()
  let playerSignals: Array<[AstalMpris.Player, number]> = []

  function syncSelected() {
    const player = selectedId() ? tracked.get(selectedId()!) : undefined
    setTitle(player?.title ?? "")
    setArtist(player?.artist || player?.identity || "")
    setPlaying(player?.playbackStatus === AstalMpris.PlaybackStatus.PLAYING)
    const canChangePlayback = player?.playbackStatus === AstalMpris.PlaybackStatus.PLAYING
      ? player.canPause
      : player?.canPlay
    setCanToggle(Boolean(player?.canControl && canChangePlayback))
    setCanNext(Boolean(player?.canControl && player.canGoNext))
  }

  function refreshPlayers() {
    for (const [player, id] of playerSignals) player.disconnect(id)
    const available = mpris.players
    tracked = new Map(available.map(player => [player.busName, player]))
    setPlayers(available.map(player => ({ id: player.busName, name: playerName(player) })))
    playerSignals = available.flatMap(player => [
      [player, player.connect("notify::metadata", syncSelected)] as [AstalMpris.Player, number],
      [player, player.connect("notify::playback-status", syncSelected)] as [AstalMpris.Player, number],
      [player, player.connect("notify::can-control", syncSelected)] as [AstalMpris.Player, number],
      [player, player.connect("notify::can-play", syncSelected)] as [AstalMpris.Player, number],
      [player, player.connect("notify::can-pause", syncSelected)] as [AstalMpris.Player, number],
      [player, player.connect("notify::can-go-next", syncSelected)] as [AstalMpris.Player, number],
    ])
    const current = selectedId()
    if (!current || !tracked.has(current)) {
      const preferred = available.find(player => player.playbackStatus === AstalMpris.PlaybackStatus.PLAYING) ?? available[0]
      setSelectedId(preferred?.busName ?? null)
    }
    syncSelected()
  }

  const managerSignals = [
    mpris.connect("player-added", refreshPlayers),
    mpris.connect("player-closed", refreshPlayers),
  ]
  refreshPlayers()

  return {
    players,
    selectedId,
    title,
    artist,
    playing,
    canToggle,
    canNext,
    selectPlayer(id) {
      if (!tracked.has(id)) return
      setSelectedId(id)
      syncSelected()
    },
    playPause() {
      if (selectedId()) tracked.get(selectedId()!)?.play_pause()
    },
    next() {
      if (selectedId()) tracked.get(selectedId()!)?.next()
    },
    dispose() {
      for (const id of managerSignals) mpris.disconnect(id)
      for (const [player, id] of playerSignals) player.disconnect(id)
    },
  }
}

function PlayerMenu({ media }: { media: MediaController }) {
  let popover!: Gtk.Popover
  const selectedLabel = media.selectedId(id => media.players().find(player => player.id === id)?.name ?? "Select player")
  return <menubutton hexpand tooltipText={selectedLabel} sensitive={media.players(value => value.length > 0)}>
    <box spacing={8}>
      <label label={selectedLabel} xalign={0} hexpand maxWidthChars={36} ellipsize={Pango.EllipsizeMode.END}/>
      <image iconName="pan-down-symbolic"/>
    </box>
    <popover $={self => { popover = self }}>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <For each={media.players}>
          {(player: MediaPlayerOption) => <button
            tooltipText={`Select player: ${player.name}`}
            cssClasses={media.selectedId(id => id === player.id ? ["chosen"] : [])}
            onClicked={() => {
              media.selectPlayer(player.id)
              popover.popdown()
            }}>
            <label label={player.name} xalign={0} maxWidthChars={40} ellipsize={Pango.EllipsizeMode.END}/>
          </button>}
        </For>
      </box>
    </popover>
  </menubutton>
}

export function MediaPanel({ media }: { media: MediaController }) {
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={10} cssClasses={["media-page", "widget-card"]}>
    <box spacing={8}>
      <label label="NOW PLAYING" xalign={0} hexpand cssClasses={["section-title"]}/>
      <PlayerMenu media={media}/>
    </box>
    <label
      visible={media.selectedId(id => id === null)}
      label="No media player is available."
      xalign={0}
      cssClasses={["hint"]}/>
    <box visible={media.selectedId(id => id !== null)} orientation={Gtk.Orientation.VERTICAL} spacing={4}>
      <label
        label={media.title(value => value || "No track information")}
        tooltipText={media.title}
        xalign={0}
        maxWidthChars={42}
        ellipsize={Pango.EllipsizeMode.END}/>
      <label
        label={media.artist}
        tooltipText={media.artist}
        visible={media.artist(Boolean)}
        xalign={0}
        maxWidthChars={42}
        ellipsize={Pango.EllipsizeMode.END}
        cssClasses={["hint"]}/>
      <box spacing={8} homogeneous>
        <button
          label={media.playing(value => value ? "Pause" : "Play")}
          tooltipText="Play or pause"
          sensitive={media.canToggle}
          onClicked={() => media.playPause()}/>
        <button label="Next" tooltipText="Next track" sensitive={media.canNext} onClicked={() => media.next()}/>
      </box>
    </box>
  </box>
}
