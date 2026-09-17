// Read-only backend smoke plus deterministic helper tests by default.
// Set AGS_TEST_NETWORK_SCAN=1 to opt into one real scan; it never activates or disconnects a network.

import app from "ags/gtk4/app"
import AstalNetwork from "gi://AstalNetwork"
import GLib from "gi://GLib?version=2.0"
import NM from "gi://NM?version=1.0"
import { connectionMode, createNetwork, networkIdentity, newConnection, securityFor, securityIdentityFor, waitForScanCompletion } from "../network"
import type { WifiAccessPoint, WifiSecurity } from "../network"

const LIVE_SCAN = GLib.getenv("AGS_TEST_NETWORK_SCAN") === "1"

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message)
}

function accessPoint(security: number, privacy = 0) {
  return {
    get_flags: () => privacy as NM.__80211ApFlags,
    get_wpa_flags: () => 0 as NM.__80211ApSecurityFlags,
    get_rsn_flags: () => security as NM.__80211ApSecurityFlags,
    get_ssid: () => new GLib.Bytes("SFO"),
  }
}

function point(security: WifiSecurity): WifiAccessPoint {
  return {
    id: `${security}:53464f`,
    name: "SFO",
    strength: 100,
    iconName: "network-wireless-signal-excellent-symbolic",
    active: false, saved: false, security,
  }
}

function scanHarness(initial: number) {
  let lastScan = initial
  let changed = () => {}
  let timedOut = () => {}
  let cleanupCount = 0
  return {
    source: {
      lastScan: () => lastScan,
      onChange(callback: () => void) {
        changed = callback
        return () => {
          cleanupCount += 1
          changed = () => {}
        }
      },
      onTimeout(callback: () => void) {
        timedOut = callback
        return () => {
          cleanupCount += 1
          timedOut = () => {}
        }
      },
    },
    advance(value: number) {
      lastScan = value
      changed()
    },
    expire() {
      timedOut()
    },
    cleanupCount: () => cleanupCount,
  }
}

async function testScanCompletion() {
  const completed = scanHarness(10)
  let settled = false
  const pending = waitForScanCompletion(10, completed.source).then(result => {
    settled = true
    return result
  })
  completed.advance(10)
  assert(!settled, "An unchanged last-scan value completed the scan")
  completed.advance(11)
  assert(await pending, "An advanced last-scan value did not complete the scan")
  assert(completed.cleanupCount() === 2, "Completed scan observers were not removed")

  const expired = scanHarness(20)
  const timeout = waitForScanCompletion(20, expired.source)
  expired.expire()
  assert(!(await timeout), "A scan timeout was reported as complete")
  assert(expired.cleanupCount() === 2, "Timed-out scan observers were not removed")
}

function testIdentity() {
  const bytes = new Uint8Array([0x74, 0x65, 0x73, 0x74])
  assert(networkIdentity(bytes, "personal-psk") === networkIdentity(bytes, "personal-psk"), "Network identity is not deterministic")
  assert(networkIdentity(bytes, "personal-psk") !== networkIdentity(bytes, "open"), "Security mode is absent from network identity")
  const sfo = new Uint8Array([0x53, 0x46, 0x4f])
  assert(networkIdentity(sfo, "owe") !== networkIdentity(sfo, "open"), "OWE shares an identity with ordinary open Wi-Fi")
}

function testSecurityClassification() {
  const open = accessPoint(0)
  const oweTransition = accessPoint(4096)
  const owe = accessPoint(2184, 1)
  const pskOwe = accessPoint(0x100 | 0x800)
  const sae = accessPoint(0x400)
  const enterprise = accessPoint(0x200)
  const enterpriseOwe = accessPoint(0x200 | 0x800)
  assert(securityFor(open) === "open" && securityIdentityFor(open) === "open", "Open Wi-Fi classification changed")
  assert(securityFor(oweTransition) === "owe" && securityIdentityFor(oweTransition) === "owe", "SFO OWE transition flags were not recognized")
  assert(securityFor(owe) === "owe" && securityIdentityFor(owe) === "owe", "SFO OWE flags were not recognized")
  assert(securityFor(pskOwe) === "personal" && securityIdentityFor(pskOwe) === "personal-psk", "PSK did not take precedence over OWE")
  assert(securityFor(sae) === "personal" && securityIdentityFor(sae) === "personal-sae", "SAE classification changed")
  assert(securityFor(enterprise) === "enterprise" && securityIdentityFor(enterprise) === "enterprise", "Enterprise classification changed")
  assert(securityFor(enterpriseOwe) === "enterprise" && securityIdentityFor(enterpriseOwe) === "enterprise", "Enterprise did not take precedence over OWE")
}

function testProfiles() {
  const open = newConnection(point("open"), accessPoint(0))
  assert(open.verify(), "Open profile does not pass libnm validation")
  assert(!open.get_setting_wireless_security(), "Open profile unexpectedly has security settings")

  for (const raw of [accessPoint(4096), accessPoint(2184, 1)]) {
    const owe = newConnection(point("owe"), raw, "must-not-be-used")
    const oweWireless = owe.get_setting_wireless()
    const oweSecurity = owe.get_setting_wireless_security()
    assert(owe.verify() && oweWireless && oweSecurity?.get_key_mgmt() === "owe", "OWE profile is not a valid key-mgmt=owe libnm profile")
    assert(!oweSecurity.get_psk() && owe.need_secrets()[0] === null, "OWE profile contains or requests a secret")
    assert(oweWireless.ap_security_compatible(
      oweSecurity,
      raw.get_flags(),
      raw.get_wpa_flags(),
      raw.get_rsn_flags(),
      2 as NM.__80211Mode,
    ), "OWE profile is incompatible with observed SFO flags")
  }

  const psk = newConnection(point("personal"), accessPoint(0x100), "password1")
  const pskSecurity = psk.get_setting_wireless_security()
  assert(psk.verify() && pskSecurity?.get_key_mgmt() === "wpa-psk" && pskSecurity.get_psk() === "password1", "PSK profile creation changed")

  const sae = newConnection(point("personal"), accessPoint(0x400), "password1")
  const saeSecurity = sae.get_setting_wireless_security()
  assert(sae.verify() && saeSecurity?.get_key_mgmt() === "sae" && saeSecurity.get_psk() === "password1", "SAE profile creation changed")
}

function testConnectionModes() {
  assert(connectionMode(0, false, "open") === "new", "No-profile activation did not create a new profile")
  assert(connectionMode(1, false, "personal") === "existing", "Single-profile activation did not use that profile")
  assert(connectionMode(2, false, "personal") === "automatic", "Duplicate-profile activation did not defer selection to NetworkManager")
  assert(connectionMode(1, true, "personal") === "retry", "Single-profile password retry did not target that profile")
  assert(connectionMode(2, true, "personal") === "new", "Duplicate-profile password retry could overwrite an existing profile")
  assert(connectionMode(0, false, "owe") === "new", "OWE without a saved profile did not create one")
  assert(connectionMode(1, false, "owe") === "existing", "OWE did not explicitly select its saved profile")
  assert(connectionMode(2, false, "owe") === "existing", "OWE duplicate profiles allowed automatic unsecured fallback")
}

async function testRealBackend(): Promise<number> {
  const network = createNetwork()
  try {
    const points = network.accessPoints()
    const ids = new Set(points.map(point => point.id))
    assert(ids.size === points.length, "The live NetworkManager snapshot contains duplicate logical identities")
    assert(points.every(point => /^(open|owe|personal-psk|personal-sae|enterprise|unsupported):[0-9a-f]+$/.test(point.id)),
      "The live NetworkManager snapshot contains a BSSID-based identity")
    const wifi = AstalNetwork.get_default().get_wifi()
    const device = wifi?.get_device() ?? null
    if (!wifi || !device) {
      assert(!LIVE_SCAN, "The opt-in Wi-Fi scan requires an available adapter")
      assert(!network.available, "The controller reports an unavailable Wi-Fi adapter as available")
      assert(network.summary() === "Wi-Fi unavailable", "The unavailable Wi-Fi summary is incorrect")
      assert(!network.enabled() && !network.scanning() && !network.busy(), "The unavailable Wi-Fi controller has active state")
      assert(network.status() === "" && points.length === 0, "The unavailable Wi-Fi controller exposes status or access points")
      await network.scan()
      await network.setWifiEnabled(true)
      const result = await network.connect(point("open"))
      assert(!result.connected && !result.needsPassword, "The unavailable Wi-Fi controller accepted a connection")
      assert(!network.enabled() && !network.scanning() && !network.busy() && network.status() === "" && network.accessPoints().length === 0,
        "An unavailable Wi-Fi operation changed controller state")
      return 0
    }
    assert(network.available, "The controller reports an available Wi-Fi adapter as unavailable")
    let checkedOweProfiles = 0
    for (const raw of device.get_access_points()) {
      if (securityFor(raw) !== "owe" || !raw.get_ssid()) continue
      const candidate = newConnection(point("owe"), raw)
      assert(candidate.verify(), "A cached OWE access point produced an invalid libnm profile")
      assert(raw.connection_valid(candidate) && device.connection_valid(candidate), "A cached OWE access point rejected its candidate profile")
      checkedOweProfiles += 1
    }
    if (LIVE_SCAN) {
      assert(network.enabled(), "Wi-Fi is off; the opt-in scan cannot run")
      await network.scan()
      assert(!network.scanning() && network.status() === "Wi-Fi scan complete.", "The opt-in NetworkManager scan did not complete")
    }
    return checkedOweProfiles
  } finally {
    network.dispose()
  }
}

async function run() {
  await testScanCompletion()
  testIdentity()
  testSecurityClassification()
  testProfiles()
  testConnectionModes()
  const checkedOweProfiles = await testRealBackend()
  print(`ags-wifi-backend: PASS (${LIVE_SCAN ? "opt-in scan completed; no activation requested" : "read-only"}; cached OWE profiles checked: ${checkedOweProfiles})`)
}

app.start({
  instanceName: "ags-wifi-backend-test",
  main() {
    void run().then(() => app.quit()).catch(error => {
      printerr(`ags-wifi-backend: FAIL: ${error instanceof Error ? error.message : String(error)}`)
      app.quit(1)
    })
  },
})
