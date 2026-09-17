# Design system

The style uses square corners, black outlines, monospace text, and accent colors
across the bar, launcher, terminal, lock screen, and login manager.

## Geometry and text

Hyprland uses 3-pixel borders, 5-pixel inner gaps, and 8-pixel outer gaps. Window
rounding and blur are disabled. Kitty uses 0.85 background opacity and provides
shortcuts to adjust it. The bar and control panels also appear on connected
external displays.

JetBrains Mono Nerd Font supplies text and interface glyphs. Install
`ttf-jetbrains-mono-nerd` to avoid missing symbols.

## Palette

| Color | Hex | Use |
| --- | --- | --- |
| Yellow | `#FFBE0B` | Default accent |
| Mint | `#06FFA5` | Positive and selected states |
| Pink | `#FF006E` | Warning and urgent states |
| Purple | `#8338EC` | Alternate accent and mode indicators |
| Blue | `#3A86FF` | Alternate accent |
| Orange | `#FB5607` | Alternate accent |
| Black | `#000000` | Borders and dark text |
| White | `#FFFFFF` | Light surfaces and text |

Eight palettes change accents and text colors while keeping the geometry.
[Switch themes](../how-to/switch-themes.md) through the appearance panel or the
keyboard shortcut. Login and lock-screen styling are configured separately.

## Portable defaults

The public desktop keeps the Framework 12 layout and controls but uses generic
monitor rules. Monitor serials, Bluetooth addresses, weather coordinates, and
personal workspace state belong in local settings.

Reusable code stays in the repository. Downloaded runtimes, JavaScript
dependencies, build output, private shell additions, and session logs do not.
