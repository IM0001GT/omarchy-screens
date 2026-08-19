# Screens

An Omarchy bar widget for arranging displays and setting how they look.

Click the two-tile mark for a panel that stays open. Displays are drawn at their real Hyprland size. Drag them and they **snap flush** — no overlapping tiles, no cursor-eating gaps. Then set brightness, text size, resolution, refresh, HDR, VRR, scale, rotation, and mirroring. Save the desk as a named **profile**; Screens can restore it when a display is plugged in.

<p align="center">
  <img width="497" height="761" alt="Screens panel" src="https://github.com/user-attachments/assets/94012df0-bf3a-4e7d-bfcc-08cee6dfcb16" />
</p>

| Layout | This screen | HDR | Profiles |
| --- | --- | --- | --- |
| Drag tiles; edges snap | Brightness, text size, resolution, Hz, scale, rotation, mirror, Detect | 8-bit or 10-bit PQ, Tune for black / peak | Name a desk; restore on connect |

Works with two screens or a full battlestation. A fallback Hyprland rule still catches anything you hot-plug later. The panel scrolls when it is taller than the screen, so controls stay reachable at large scale (for example 2× on 1080p).

Stock **Display** can stay on the bar if you want it. Screens uses a different icon on purpose.

## Why this exists

Omarchy's Display widget does brightness, text size, and scale. It does not arrange monitors or expose HDMI 2.1 features.

Other listed tools cover adjacent jobs:

- **Stock Display** — backlight, font size, scale presets, enable/disable
- **hyprmoncfg** — named profiles and a hotplug daemon, via an external TUI the bar only launches
- **Generic layout editors** — often reuse the stock monitor glyph, skip snap, and leave HDR/VRR in `monitors.lua`

Screens keeps the editor in the bar, follows the theme, and writes Hyprland Lua only after you act. No AUR package. No extra daemon.

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

The first time Screens sees `~/.config/hypr/monitors.lua`, it copies that file to `~/.local/state/im0001gt.screens/original-monitors.lua` and never overwrites it.

## Use

**Layout**

- **Click** the two-tile icon — the panel stays open until you click away
- **Drag** a tile — edges snap so the cursor never falls in a gap
- **Find** — badge on the *selected* output (not only the screen that holds the menu)
- **Detect** — rescan Hyprland and DRM for a plugged-in screen that is currently off, then **Turn on**. If it is listed but stays blank, restart Hyprland or the machine
- **Enable this Display** turns a screen off. On a non-primary GPU that can leave the panel blank until Hyprland or a reboot; Detect still finds it
- **Make primary** chooses which screen the panel prefers when it opens

**This screen**

- Pick a screen, then set **brightness**, **text size**, **resolution**, **refresh**, **scale**, **orientation**, or **mirror**
- Brightness follows the selected output (internal backlight or DDC). It hides when that output has no backlight. A short label (Night owl, Golden hour, and so on) shows in the panel header while you drag the slider
- Text size uses Omarchy's 9–20 px stops and applies to the shell, GTK, and terminals
- Laptop built-in panels are written as `eDP-1` / `LVDS` / `DSI` so Omarchy's clamshell helper keeps your scale instead of forcing 2
- Labels use Hyprland's model string

**HDR and VRR**

- **HDR**: **Off**, **Auto**, or **Always**. Auto keeps the desktop in SDR and only switches to HDR for fullscreen games and video (`cm_auto_hdr`). Always leaves PQ on all the time and can wash out HDR-ready LCDs
- **Tune** (Auto or Always): 8-bit or 10-bit, color space, SDR brightness, black floor, and SDR peak
- Color space **Display** uses this panel's EDID primaries. **Wide** is BT.2020. HDR-ready LCDs that are not full wide-gamut should stay on Display
- HDR and VRR disable themselves when that panel cannot do them
- VRR modes: Off, Always, Fullscreen, Games & video. Always + HDR can flicker on some OLEDs; Fullscreen or Games & video is the usual workaround

**Profiles**

- **Save** names the current layout. Click the profile name (or **Apply**) to write it. Two or more profiles become a dropdown
- **On connect** reapplies a matching profile when a display is plugged in
- Turning a display on, or turning **Mirror** off, restores the matching saved layout instead of leaving tiles stacked

Changes write `~/.config/hypr/monitors.lua` after you drag, turn a display on, or save. Later applies keep a short rolling set of timestamped copies in `~/.local/state/im0001gt.screens/`. Stock Omarchy monitor files are replaced; other custom files keep their text and get a managed block appended.

Move it with `omarchy bar move im0001gt.screens`.

## Multi-GPU desks

If Hyprland is painting on one GPU and another panel is plugged into a second GPU, idle standby or **Enable this Display** off can leave that output blank until Hyprland or a reboot. Screens only Hyprland-DPMS the **primary** GPU on idle; any display on another GPU stays on but black. Detect can still find a disabled output. A one-time note appears the first time you open the panel.

Resolution lists come from Hyprland / the EDID. A DP-to-DVI adapter that only advertises 2560×1440@60 will only show that mode.

## Update

```bash
omarchy plugin update im0001gt.screens --yes
omarchy restart shell
```

## Uninstall

```bash
omarchy plugin remove im0001gt.screens
```

Removing the plugin does not restore `monitors.lua`. The last layout Screens wrote stays in `~/.config/hypr/monitors.lua`. The first-install copy and profiles stay in `~/.local/state/im0001gt.screens/`.

To restore the layout from before Screens:

```bash
~/.config/omarchy/plugins/im0001gt.screens/scripts/display-ctl restore-original
```

If you already removed the plugin:

```bash
cp ~/.local/state/im0001gt.screens/original-monitors.lua ~/.config/hypr/monitors.lua
hyprctl reload
```

## Requirements

- [Omarchy](https://omarchy.org/) with the shell plugin CLI (`omarchy plugin add`)
- Hyprland 0.55+ Lua monitor config (`hl.monitor`)
- `python3` and `jq` (already on Omarchy)

Hyprland HDR is PQ (`cm = hdr` or `hdredid`) at 8-bit or 10-bit. There is no HLG preset. Some capture tools do not like 10-bit.

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
