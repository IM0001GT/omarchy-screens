# Screens

An Omarchy bar widget that treats the desk as a layout, not a list of percentages.

Click the two-tile mark for a Power-style panel that stays open. Displays are drawn at their real Hyprland size. Drag them and they **snap flush** — no overlapping tiles, no cursor-eating gaps. Then set refresh, HDR, VRR, scale, rotation, and mirroring on the selected screen. Save the desk as a named **profile**; Screens can restore it when a display is plugged in.

Stock **Display** stays put (brightness and text size). Screens uses a different icon on purpose.

<p align="center">
  <img src="preview.png" alt="Screens panel with a snap layout canvas, named profile, and per-display refresh, HDR, and VRR" width="360">
</p>

| Click | Drag | Per screen | Profiles |
| --- | --- | --- | --- |
| Open the panel | Snap tiles to neighboring edges | Resolution, Hz, HDR, four VRR modes, scale, rotation, mirror, enable | Name a desk, restore it on connect |

Works with two screens or a full battlestation. A fallback Hyprland rule still catches anything you hot-plug later.

## Why this exists

Omarchy Quattro's Display widget does brightness, text size, and scale. It does not arrange monitors or expose HDMI 2.1 features.

Other listed tools cover adjacent jobs:

- **Stock Display** — backlight, font size, scale presets, enable/disable
- **hyprmoncfg** — named profiles and a hotplug daemon, via an external TUI the bar only launches
- **Generic layout editors** — often reuse the stock monitor glyph, skip snap, and leave HDR/VRR in `monitors.lua`

Screens is the other thing: the editor lives in the bar, follows the theme, and writes Hyprland Lua only after you act. No AUR package. No extra daemon.

## Install

Plugins run as unsandboxed code inside `omarchy-shell`. Only add repos you trust.

```bash
omarchy plugin add https://github.com/IM0001GT/omarchy-screens --enable
```

That clones into `~/.config/omarchy/plugins/im0001gt.screens/` and can drop the widget on the right side of the bar, next to Display.

### One-shot from a clone

```bash
git clone https://github.com/IM0001GT/omarchy-screens.git
cd omarchy-screens
./install.sh
```

## Use

- **Click** the two-tile icon — the panel stays open until you click away
- **Drag** a tile — edges snap so the cursor never falls in a gap
- **Find** — badge on the *selected* output (not only the screen that holds the menu)
- Pick a screen, then set **resolution**, **refresh**, **HDR**, **VRR**, **scale**, **orientation**, or **mirror**
- **Save** names the current layout. Two or more profiles become a dropdown. **On connect** reapplies a matching profile when a display is plugged in
- Labels use Hyprland's model string. HDR and VRR disable themselves when that panel cannot do them
- **Make primary** chooses which screen the panel prefers when it opens

Changes write `~/.config/hypr/monitors.lua` after you drag, toggle, or save. Backups and profiles land in `~/.local/state/im0001gt.screens/`. Stock Omarchy monitor files are replaced; other custom files keep their text and get a managed block appended.

Move it with `omarchy bar move im0001gt.screens`.

## Update

```bash
omarchy plugin update im0001gt.screens --yes
omarchy restart shell
```

## Uninstall

```bash
omarchy plugin remove im0001gt.screens
```

Your last `monitors.lua` stays in place. Backups and profiles are not deleted.

## Requirements

- [Omarchy](https://omarchy.org/) with the shell plugin CLI (`omarchy plugin add`)
- Hyprland 0.55+ Lua monitor config (`hl.monitor`)
- `python3` and `jq` (already on Omarchy)

HDR is 10-bit PQ (`cm = hdr`, `bitdepth = 10`). Some capture tools do not like 10-bit. VRR is Hyprland's four modes: Off, Always, Fullscreen, and Games & video. Always + HDR can flicker on some OLEDs; Fullscreen or Games & video is the usual workaround.

## Layout

```text
manifest.json          Omarchy plugin manifest (must live at repo root)
Screens.qml            Bar icon + click panel
ScreenMark.qml         Two-tile bar/hero mark
Model.js               Snap / normalize / mode helpers
scripts/display-ctl    hyprctl snapshot + monitors.lua writer
preview.png            Marketplace still
install.sh             Enable / place the widget
```

The repo root **is** the plugin. That is what `omarchy plugin add` and `omarchy plugin validate` expect.

## License

MIT. See [LICENSE](LICENSE).
