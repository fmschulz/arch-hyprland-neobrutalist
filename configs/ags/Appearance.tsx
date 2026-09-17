import { createState } from "ags"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import Gdk from "gi://Gdk?version=4.0"
import GdkPixbuf from "gi://GdkPixbuf?version=2.0"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"

export const machineRoot = GLib.getenv("AGS_ROOT") ?? GLib.get_user_config_dir()
export const script = (name: string) => `${machineRoot}/scripts/${name}.sh`
export const paletteNames = ["yellow", "blue", "purple", "green", "orange", "black", "darkgrey", "white"]

function read(path: string): string {
  return new TextDecoder().decode(GLib.file_get_contents(path)[1])
}

function link(path: string): string {
  try { return GLib.file_read_link(path) } catch { return "" }
}

export function createAppearance() {
  const config = GLib.get_user_config_dir()
  const cache = `${GLib.get_user_cache_dir()}/wallpaper-cycle/current`
  const themesDir = `${config}/arch-hypr-neobrutalist/themes`
  const wallpapersDir = GLib.getenv("WALLPAPER_DIR") ?? `${GLib.get_home_dir()}/Pictures/wallpapers`
  const [message, setMessage] = createState("")
  const [busy, setBusy] = createState(false)
  const palette = new Gtk.CssProvider()
  Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default()!, palette, Gtk.STYLE_PROVIDER_PRIORITY_USER + 1)
  const colors = paletteNames.map(name => {
    const css = read(`${themesDir}/${name}/waybar.css`)
    const color = (key: string) => css.match(new RegExp(`@define-color ${key} (#[0-9A-Fa-f]+);`))![1]
    return {
      name,
      accent: color("accent"),
      text: color("accent-text"),
      select: color("select"),
      selectText: color("select-text"),
      good: color("good"),
      goodText: color("good-text"),
    }
  })
  let applied = ""
  const theme = createPoll("", 1000, () => {
    const name = link(`${config}/wofi/theme.css`).split("/").at(-2) ?? "yellow"
    if (name !== applied) {
      const selected = colors.find(color => color.name === name) ?? colors[0]
      palette.load_from_string(`
        @define-color accent ${selected.accent};
        @define-color accent_text ${selected.text};
        @define-color selected ${selected.select};
        @define-color selected_text ${selected.selectText};
        @define-color good ${selected.good};
        @define-color good_text ${selected.goodText};
        ${colors.map(color => `.palette-${color.name} { background: ${color.accent}; color: ${color.text}; }`).join("\n")}
      `)
      applied = name
    }
    return name
  })
  const wallpaper = createPoll("", 1000, () => link(cache))
  const images: string[] = []
  const directory = Gio.File.new_for_path(wallpapersDir)
  if (directory.query_exists(null)) {
    const entries = directory.enumerate_children("standard::name,standard::type", Gio.FileQueryInfoFlags.NONE, null)
    let entry: Gio.FileInfo | null
    while ((entry = entries.next_file(null))) {
      if (entry.get_file_type() === Gio.FileType.REGULAR && /\.(png|jpe?g|webp)$/i.test(entry.get_name())) {
        images.push(`${wallpapersDir}/${entry.get_name()}`)
      }
    }
    entries.close(null)
  }
  images.sort()

  async function apply(kind: "theme" | "wallpaper", value: string) {
    if (busy()) return
    setBusy(true)
    setMessage("")
    try {
      await execAsync(kind === "theme" ? [script("theme-set"), value] : [script("wallpaper-cycle"), "set", value])
      setMessage(kind === "theme" ? `Theme: ${value}` : "Wallpaper applied to all displays.")
    } catch {
      setMessage(kind === "theme" ? "Theme could not be applied. Check the theme-set script." : "Wallpaper was not applied. Check hyprpaper.service; your saved choice has not changed.")
    } finally { setBusy(false) }
  }
  return { theme, wallpaper, images, message, busy, apply }
}

export function AppearancePanel({ appearance }: { appearance: ReturnType<typeof createAppearance> }) {
  function thumbnail(path: string) {
    try {
      return <Gtk.Picture
        paintable={Gdk.Texture.new_for_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 144, 90, true))}
        widthRequest={120} heightRequest={76} canShrink contentFit={Gtk.ContentFit.COVER}/>
    } catch {
      return <label label="No preview" widthRequest={120} heightRequest={76} cssClasses={["hint"]}/>
    }
  }
  const rows = Array.from({ length: Math.ceil(appearance.images.length / 3) }, (_, row) => appearance.images.slice(row * 3, row * 3 + 3))
  return <box orientation={Gtk.Orientation.VERTICAL} spacing={14} cssClasses={["page"]}>
    <label label="DESKTOP PALETTE" xalign={0} cssClasses={["section-title"]}/>
    {[paletteNames.slice(0, 4), paletteNames.slice(4)].map(names =>
      <box homogeneous spacing={8}>
        {names.map(name => <button
          label={name}
          tooltipText={`Apply ${name} to the shell and existing desktop components`}
          cssClasses={appearance.theme(current => [`palette-${name}`, ...(current === name ? ["chosen"] : [])])}
          sensitive={appearance.busy(busy => !busy)}
          onClicked={() => void appearance.apply("theme", name)}/>) }
      </box>)}
    <label label="Uses your existing eight palettes. GTK apps keep their own theme; new Kitty windows pick up the selected colors." wrap xalign={0} cssClasses={["hint"]}/>
    <label label="WALLPAPER" xalign={0} cssClasses={["section-title"]}/>
    {rows.map(paths => <box spacing={8} homogeneous>
      {paths.map(path => <button
        tooltipText={GLib.path_get_basename(path)}
        sensitive={appearance.busy(busy => !busy)}
        cssClasses={appearance.wallpaper(current => ["wallpaper", ...(current === path ? ["chosen"] : [])])}
        onClicked={() => void appearance.apply("wallpaper", path)}>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          {thumbnail(path)}
          <label label={GLib.path_get_basename(path).replace(/\.[^.]+$/, "")} cssClasses={["hint"]}/>
        </box>
      </button>)}
    </box>)}
    <label visible={appearance.message(Boolean)} label={appearance.message} wrap xalign={0} cssClasses={["feedback"]}/>
  </box>
}
