import { createState, type Accessor } from "ags"
import AstalNetwork from "gi://AstalNetwork"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import GObject from "gi://GObject?version=2.0"
import NM from "gi://NM?version=1.0"

const AP_PRIVACY = 0x00000001
const AP_SEC_PSK = 0x00000100
const AP_SEC_802_1X = 0x00000200
const AP_SEC_SAE = 0x00000400
const AP_SEC_OWE = 0x00000800
const AP_SEC_OWE_TM = 0x00001000
const AP_SEC_EAP_SUITE_B_192 = 0x00002000
const SCAN_TIMEOUT_MS = 15_000

export type WifiSecurity = "open" | "owe" | "personal" | "enterprise" | "unsupported"
export type WifiSecurityIdentity = "open" | "owe" | "personal-psk" | "personal-sae" | "enterprise" | "unsupported"

export type WifiAccessPoint = {
  id: string
  name: string
  strength: number
  iconName: string
  active: boolean
  saved: boolean
  security: WifiSecurity
}

export type WifiConnectResult = {
  connected: boolean
  needsPassword: boolean
}

export type WifiConnectionMode = "automatic" | "existing" | "new" | "retry"

export interface NetworkController {
  summary: Accessor<string>
  enabled: Accessor<boolean>
  scanning: Accessor<boolean>
  busy: Accessor<boolean>
  status: Accessor<string>
  accessPoints: Accessor<WifiAccessPoint[]>
  scan(): Promise<void>
  setWifiEnabled(value: boolean): Promise<void>
  connect(ap: WifiAccessPoint, password?: string): Promise<WifiConnectResult>
  clear(): void
  onClear(callback: () => void): () => void
  dispose(): void
}

function errorMessage(error: unknown): string {
  return error instanceof Error && error.message ? error.message : "Unknown NetworkManager error"
}

export function securityFor(ap: Pick<NM.AccessPoint, "get_flags" | "get_wpa_flags" | "get_rsn_flags">): WifiSecurity {
  const security = ap.get_wpa_flags() | ap.get_rsn_flags()
  if (security & (AP_SEC_802_1X | AP_SEC_EAP_SUITE_B_192)) return "enterprise"
  if (security & (AP_SEC_PSK | AP_SEC_SAE)) return "personal"
  if (security & (AP_SEC_OWE | AP_SEC_OWE_TM)) return "owe"
  if (!(ap.get_flags() & AP_PRIVACY) && security === 0) return "open"
  return "unsupported"
}

export function securityIdentityFor(ap: Pick<NM.AccessPoint, "get_flags" | "get_wpa_flags" | "get_rsn_flags">): WifiSecurityIdentity {
  const security = ap.get_wpa_flags() | ap.get_rsn_flags()
  if (security & (AP_SEC_802_1X | AP_SEC_EAP_SUITE_B_192)) return "enterprise"
  if (security & AP_SEC_PSK) return "personal-psk"
  if (security & AP_SEC_SAE) return "personal-sae"
  if (security & (AP_SEC_OWE | AP_SEC_OWE_TM)) return "owe"
  if (!(ap.get_flags() & AP_PRIVACY) && security === 0) return "open"
  return "unsupported"
}

function ssidBytes(ap: NM.AccessPoint): Uint8Array | null {
  const ssid = ap.get_ssid()
  if (!ssid) return null
  const bytes = ssid.get_data()
  if (!bytes || bytes.length === 0) return null
  return bytes
}

export function networkIdentity(bytes: Uint8Array, security: WifiSecurityIdentity): string {
  const ssid = Array.from(bytes, byte => byte.toString(16).padStart(2, "0")).join("")
  return `${security}:${ssid}`
}

export function connectionMode(savedCount: number, passwordProvided: boolean, security: WifiSecurity): WifiConnectionMode {
  if (security === "owe") return savedCount > 0 ? "existing" : "new"
  if (savedCount === 1) return passwordProvided ? "retry" : "existing"
  if (savedCount > 1 && !passwordProvided) return "automatic"
  return "new"
}

export function waitForScanCompletion(
  initial: number,
  source: {
    lastScan(): number
    onChange(callback: () => void): () => void
    onTimeout(callback: () => void): () => void
  },
): Promise<boolean> {
  return new Promise(resolve => {
    let settled = false
    const cleanups: Array<() => void> = []
    const finish = (completed: boolean) => {
      if (settled) return
      settled = true
      for (const cleanup of cleanups.splice(0)) cleanup()
      resolve(completed)
    }
    const register = (cleanup: () => void) => settled ? cleanup() : cleanups.push(cleanup)
    register(source.onChange(() => {
      if (source.lastScan() > initial) finish(true)
    }))
    register(source.onTimeout(() => finish(false)))
    if (source.lastScan() > initial) finish(true)
  })
}

function requestScan(device: NM.DeviceWifi, cancellable: Gio.Cancellable): Promise<void> {
  return new Promise((resolve, reject) => {
    device.request_scan_async(cancellable, (_source, result) => {
      try {
        device.request_scan_finish(result)
        resolve()
      } catch (error) {
        reject(error)
      }
    })
  })
}

function activateConnection(
  client: NM.Client,
  connection: NM.Connection | null,
  device: NM.DeviceWifi,
  ap: NM.AccessPoint,
  cancellable: Gio.Cancellable,
): Promise<NM.ActiveConnection> {
  return new Promise((resolve, reject) => {
    client.activate_connection_async(connection, device, ap.get_path(), cancellable, (_source, result) => {
      try {
        resolve(client.activate_connection_finish(result))
      } catch (error) {
        reject(error)
      }
    })
  })
}

function addAndActivateTemporaryConnection(
  client: NM.Client,
  connection: NM.Connection,
  device: NM.DeviceWifi,
  ap: NM.AccessPoint,
  persist: "memory" | "volatile",
  cancellable: Gio.Cancellable,
): Promise<NM.ActiveConnection> {
  return new Promise((resolve, reject) => {
    const options = new GLib.Variant("a{sv}", { persist: new GLib.Variant("s", persist) })
    client.add_and_activate_connection2(connection, device, ap.get_path(), options, cancellable, (_source, result) => {
      try {
        const [active] = client.add_and_activate_connection2_finish(result)
        resolve(active)
      } catch (error) {
        reject(error)
      }
    })
  })
}

function deleteConnection(connection: NM.RemoteConnection, cancellable: Gio.Cancellable): Promise<void> {
  return new Promise((resolve, reject) => {
    connection.delete_async(cancellable, (_source, result) => {
      try {
        connection.delete_finish(result)
        resolve()
      } catch (error) {
        reject(error)
      }
    })
  })
}

function commitConnection(connection: NM.RemoteConnection, cancellable: Gio.Cancellable): Promise<void> {
  return new Promise((resolve, reject) => {
    connection.commit_changes_async(true, cancellable, (_source, result) => {
      try {
        connection.commit_changes_finish(result)
        resolve()
      } catch (error) {
        reject(error)
      }
    })
  })
}

export function newConnection(ap: WifiAccessPoint, raw: Pick<NM.AccessPoint, "get_ssid" | "get_wpa_flags" | "get_rsn_flags">, password?: string): NM.SimpleConnection {
  const connection = new NM.SimpleConnection()
  connection.add_setting(new NM.SettingConnection({
    id: ap.name,
    uuid: NM.utils_uuid_generate(),
    type: "802-11-wireless",
  }))
  connection.add_setting(new NM.SettingWireless({ ssid: raw.get_ssid() }))
  if (ap.security === "personal") {
    const flags = raw.get_wpa_flags() | raw.get_rsn_flags()
    connection.add_setting(new NM.SettingWirelessSecurity({
      keyMgmt: flags & AP_SEC_PSK ? "wpa-psk" : "sae",
      psk: password,
    }))
  } else if (ap.security === "owe") {
    connection.add_setting(new NM.SettingWirelessSecurity({ keyMgmt: "owe" }))
  }
  return connection
}

function retryConnection(saved: NM.RemoteConnection, password: string): NM.Connection {
  const connection = NM.SimpleConnection.new_clone(saved)
  const metadata = connection.get_setting_connection()
  const security = connection.get_setting_wireless_security()
  if (!metadata || !security) throw new Error("The saved profile has no personal Wi-Fi security setting")
  metadata.uuid = NM.utils_uuid_generate()
  metadata.id = `${metadata.id} (temporary)`
  security.psk = password
  security.psk_flags = NM.SettingSecretFlags.NONE
  return connection
}

export function createNetwork(): NetworkController {
  const service = AstalNetwork.get_default()
  const detectedWifi = service.get_wifi()
  if (!detectedWifi) throw new Error("No Wi-Fi device is available")
  const wifi: AstalNetwork.Wifi = detectedWifi

  const client = service.get_client()
  const device = wifi.get_device()
  const [summary, setSummary] = createState("Wi-Fi")
  const [enabled, setEnabled] = createState(wifi.get_enabled())
  const [scanning, setScanning] = createState(false)
  const [busy, setBusy] = createState(false)
  const [status, setStatus] = createState("")
  const [accessPoints, setAccessPoints] = createState<WifiAccessPoint[]>([])
  const signalIds: Array<[GObject.Object, number]> = []
  const rawAccessPoints = new Map<string, NM.AccessPoint>()
  const cancellables = new Set<Gio.Cancellable>()
  const pendingWaits = new Set<() => void>()
  const clearCallbacks = new Set<() => void>()
  let disposed = false

  function matchingConnections(ap: NM.AccessPoint): NM.RemoteConnection[] {
    const owe = securityFor(ap) === "owe"
    return client.get_connections().filter(connection =>
      device.connection_valid(connection)
      && ap.connection_valid(connection)
      && (!owe || connection.get_setting_wireless_security()?.get_key_mgmt() === "owe"),
    )
  }

  function refreshAccessPoints() {
    const sources = wifi.get_access_points() as AstalNetwork.AccessPoint[]
    const active = wifi.get_active_access_point()
    const strongest = new Map<string, WifiAccessPoint>()
    const rawByIdentity = new Map<string, NM.AccessPoint>()
    for (const source of sources) {
      const raw = device.get_access_point_by_path(source.get_path())
      const bytes = raw && ssidBytes(raw)
      const name = source.get_ssid()
      if (!raw || !bytes || !name) continue
      const key = networkIdentity(bytes, securityIdentityFor(raw))
      const candidate: WifiAccessPoint = {
        id: key,
        name,
        strength: source.get_strength(),
        iconName: source.get_icon_name(),
        active: active?.get_path() === source.get_path(),
        saved: matchingConnections(raw).length > 0,
        security: securityFor(raw),
      }
      const current = strongest.get(key)
      if (!current || candidate.active || (!current.active && candidate.strength > current.strength)) {
        strongest.set(key, candidate)
        rawByIdentity.set(key, raw)
      }
    }
    const points = [...strongest.values()].sort((a, b) =>
      a.name.toLocaleLowerCase().localeCompare(b.name.toLocaleLowerCase())
      || a.id.localeCompare(b.id))
    rawAccessPoints.clear()
    for (const [id, raw] of rawByIdentity) rawAccessPoints.set(id, raw)
    setAccessPoints(points)
  }

  function refreshSummary() {
    const isEnabled = wifi.get_enabled()
    setEnabled(isEnabled)
    const name = wifi.get_ssid()
    const connected = wifi.get_internet() === AstalNetwork.Internet.CONNECTED
    setSummary(!isEnabled ? "Wi-Fi off" : connected && name ? `${name} ${wifi.get_strength()}%` : "Wi-Fi")
  }

  function refreshNetworkState() {
    refreshSummary()
    refreshAccessPoints()
  }

  function watch(object: GObject.Object, signal: string, callback: () => void) {
    signalIds.push([object, object.connect(signal as never, callback)])
  }

  function operationCancellable(): Gio.Cancellable {
    const cancellable = new Gio.Cancellable()
    cancellables.add(cancellable)
    return cancellable
  }

  function finishCancellable(cancellable: Gio.Cancellable) {
    cancellables.delete(cancellable)
  }

  function waitForActivation(active: NM.ActiveConnection): Promise<{ connected: boolean; reason: number }> {
    return new Promise(resolve => {
      let signalId = 0
      let settled = false
      const finish = (connected: boolean, reason: number) => {
        if (settled) return
        settled = true
        if (signalId) active.disconnect(signalId)
        pendingWaits.delete(cancel)
        resolve({ connected, reason })
      }
      const inspect = (state: NM.ActiveConnectionState, reason: number) => {
        if (state === NM.ActiveConnectionState.ACTIVATED) finish(true, reason)
        else if (state === NM.ActiveConnectionState.DEACTIVATED) finish(false, reason)
      }
      const cancel = () => finish(false, NM.ActiveConnectionStateReason.UNKNOWN)
      pendingWaits.add(cancel)
      signalId = active.connect("state-changed", (_active, state, reason) => inspect(state, reason))
      inspect(active.get_state(), active.get_state_reason())
    })
  }

  function activationFailure(name: string, reason: number): string {
    if (reason === NM.ActiveConnectionStateReason.NO_SECRETS || reason === NM.ActiveConnectionStateReason.LOGIN_FAILED) {
      return `Authentication failed for ${name}. Check the password and retry.`
    }
    if (reason === NM.ActiveConnectionStateReason.CONNECT_TIMEOUT) return `Connection to ${name} timed out.`
    return `Could not connect to ${name}.`
  }

  async function scan() {
    if (disposed || !enabled() || scanning() || busy()) return
    setScanning(true)
    setStatus("Scanning for networks…")
    const cancellable = operationCancellable()
    try {
      const initial = device.get_last_scan()
      await requestScan(device, cancellable)
      const completed = await waitForScanCompletion(initial, {
        lastScan: () => device.get_last_scan(),
        onChange(callback) {
          const id = device.connect("notify::last-scan", callback)
          return () => GObject.signal_handler_disconnect(device, id)
        },
        onTimeout(callback) {
          let timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, SCAN_TIMEOUT_MS, () => {
            timeoutId = 0
            callback()
            return GLib.SOURCE_REMOVE
          })
          const cancelledId = GObject.Object.prototype.connect.call(cancellable, "cancelled" as never, callback)
          return () => {
            if (timeoutId) GLib.source_remove(timeoutId)
            GObject.signal_handler_disconnect(cancellable, cancelledId)
          }
        },
      })
      if (disposed) return
      refreshAccessPoints()
      setStatus(completed ? "Wi-Fi scan complete." : "Wi-Fi scan timed out; showing cached networks.")
    } catch (error) {
      if (!disposed) setStatus(`Wi-Fi scan failed: ${errorMessage(error)}`)
    } finally {
      finishCancellable(cancellable)
      setScanning(false)
    }
  }

  async function setWifiEnabled(value: boolean) {
    if (busy() || value === enabled()) return
    setBusy(true)
    setStatus("")
    try {
      wifi.set_enabled(value)
      setStatus(value ? "Wi-Fi enabled." : "Wi-Fi disabled.")
    } catch (error) {
      setStatus(`Could not change Wi-Fi state: ${errorMessage(error)}`)
    } finally {
      setBusy(false)
    }
  }

  async function connect(ap: WifiAccessPoint, password?: string): Promise<WifiConnectResult> {
    if (busy()) return { connected: false, needsPassword: false }
    if (ap.active) {
      setStatus(`Already connected to ${ap.name}.`)
      return { connected: true, needsPassword: false }
    }
    if (ap.security === "enterprise") {
      try {
        Gio.Subprocess.new(["nm-connection-editor"], Gio.SubprocessFlags.NONE)
        setStatus(`Configure ${ap.name} in NetworkManager.`)
      } catch (error) {
        setStatus(`Could not open NetworkManager: ${errorMessage(error)}`)
      }
      return { connected: false, needsPassword: false }
    }
    if (ap.security === "unsupported") {
      setStatus(`${ap.name} uses a Wi-Fi security mode this panel does not support.`)
      return { connected: false, needsPassword: false }
    }

    const raw = rawAccessPoints.get(ap.id)
    if (!raw) {
      setStatus(`${ap.name} is no longer in range.`)
      return { connected: false, needsPassword: false }
    }
    const matches = matchingConnections(raw)
    const mode = connectionMode(matches.length, password !== undefined, ap.security)
    const saved = mode === "existing" || mode === "retry" ? matches[0] : undefined
    const isNewProfile = mode === "new"
    if (ap.security === "personal" && password === undefined && matches.length === 0) {
      setStatus(`Enter the password for ${ap.name}.`)
      return { connected: false, needsPassword: true }
    }

    setBusy(true)
    setStatus(matches.length > 1 && password !== undefined
      ? `Multiple saved profiles match ${ap.name}; connecting with a new profile…`
      : `Connecting to ${ap.name}…`)
    const cancellable = operationCancellable()
    try {
      const temporary = mode === "retry"
        ? retryConnection(saved!, password!)
        : isNewProfile ? newConnection(ap, raw, password) : null
      const active = temporary
        ? await addAndActivateTemporaryConnection(client, temporary, device, raw, mode === "retry" ? "volatile" : "memory", cancellable)
        : await activateConnection(client, mode === "automatic" ? null : saved!, device, raw, cancellable)
      temporary?.clear_secrets()
      const result = await waitForActivation(active)
      if (result.connected) {
        let saveError: unknown
        try {
          if (mode === "retry") {
            const security = saved!.get_setting_wireless_security()
            if (!security) throw new Error("The saved profile has no personal Wi-Fi security setting")
            security.psk = password!
            security.psk_flags = NM.SettingSecretFlags.NONE
            await commitConnection(saved!, cancellable)
            saved!.clear_secrets()
          } else if (isNewProfile) {
            const added = active.get_connection()
            const security = added.get_setting_wireless_security()
            if (password !== undefined && !security) throw new Error("The new profile has no personal Wi-Fi security setting")
            if (security && password !== undefined) {
              security.psk = password
              security.psk_flags = NM.SettingSecretFlags.NONE
            }
            try {
              await commitConnection(added, cancellable)
            } finally {
              added.clear_secrets()
            }
          }
        } catch (error) {
          saved?.clear_secrets()
          saveError = error
        }
        setStatus(saveError
          ? `Connected to ${ap.name}, but could not save the profile: ${errorMessage(saveError)}`
          : `Connected to ${ap.name}.`)
        return { connected: true, needsPassword: false }
      }
      if (isNewProfile) {
        try {
          await deleteConnection(active.get_connection(), cancellable)
        } catch {
          // The failed profile is memory-only and will not persist across NetworkManager restarts.
        }
      }
      setStatus(activationFailure(ap.name, result.reason))
      return { connected: false, needsPassword: ap.security === "personal" }
    } catch (error) {
      if (!disposed) setStatus(`Could not connect to ${ap.name}: ${errorMessage(error)}`)
      return { connected: false, needsPassword: ap.security === "personal" }
    } finally {
      finishCancellable(cancellable)
      setBusy(false)
      refreshSummary()
    }
  }

  function clear() {
    setStatus("")
    for (const callback of clearCallbacks) callback()
  }

  function onClear(callback: () => void): () => void {
    clearCallbacks.add(callback)
    return () => clearCallbacks.delete(callback)
  }

  function dispose() {
    disposed = true
    for (const cancellable of cancellables) cancellable.cancel()
    for (const cancel of [...pendingWaits]) cancel()
    for (const [object, id] of signalIds) object.disconnect(id)
    rawAccessPoints.clear()
    clearCallbacks.clear()
    signalIds.length = 0
  }

  watch(wifi, "access-point-added", refreshAccessPoints)
  watch(wifi, "access-point-removed", refreshAccessPoints)
  watch(wifi, "notify::active-access-point", refreshNetworkState)
  watch(wifi, "notify::enabled", refreshNetworkState)
  watch(wifi, "notify::internet", refreshSummary)
  watch(wifi, "notify::ssid", refreshSummary)
  watch(wifi, "notify::strength", refreshSummary)
  refreshNetworkState()

  return { summary, enabled, scanning, busy, status, accessPoints, scan, setWifiEnabled, connect, clear, onClear, dispose }
}
