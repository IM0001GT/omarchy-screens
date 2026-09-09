import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Model.js" as Model

Item {
  id: root
  property var manifest: null
  property var shell: null
  readonly property string ctl:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/im0001gt.screens/scripts/display-ctl"
  readonly property string carePath:
    Quickshell.env("HOME") + "/.local/state/im0001gt.screens/bar-care.json"

  property var careConfig: Model.normalizeBarCare(null)

  readonly property var bar: shell && shell.bar ? shell.bar : null
  readonly property bool barHovered: bar ? !!bar.barHovered : false
  readonly property bool barHidden: bar ? !!bar.barHidden : false
  readonly property bool careEnabled: !!(careConfig && careConfig.enabled)

  function parseCare(text) {
    try {
      var data = JSON.parse(text || "{}")
      root.careConfig = Model.normalizeBarCare(data)
    } catch (e) {
      root.careConfig = Model.normalizeBarCare(null)
    }
    root.applyCareVisuals()
  }

  function applyCareVisuals() {
    var bar = root.bar
    if (!bar) return
    var slots = bar.moduleSlots || []
    var on = root.careEnabled && !root.barHidden
    var i, slot, target
    for (i = 0; i < slots.length; i++) {
      slot = slots[i]
      if (!slot) continue
      target = 1
      if (on) {
        target = Model.barOpacityFor(root.careConfig, {
          hovered: root.barHovered,
          barHidden: false
        })
      }
      try { slot.opacity = target } catch (e) {}
    }
  }

  readonly property int hyprMonitorCount: {
    var vals = Hyprland.monitors && Hyprland.monitors.values
    return vals ? vals.length : 0
  }

  Component.onCompleted: {
    if (!claimProc.running) claimProc.running = true
    Qt.callLater(root.applyCareVisuals)
  }
  onHyprMonitorCountChanged: {
    if (root.hyprMonitorCount <= 0) return
    if (!recoverProc.running) recoverProc.running = true
  }
  onCareConfigChanged: root.applyCareVisuals()
  onBarHoveredChanged: root.applyCareVisuals()
  onBarHiddenChanged: root.applyCareVisuals()
  onBarChanged: root.applyCareVisuals()

  Process {
    id: claimProc
    command: [root.ctl, "claim"]
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: recoverProc
    command: [root.ctl, "recover-internal"]
    stdout: StdioCollector { waitForEnd: true }
  }

  FileView {
    id: careFile
    path: root.carePath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseCare(text())
    onLoadFailed: {
      root.careConfig = Model.normalizeBarCare(null)
      root.applyCareVisuals()
    }
    onFileChanged: reload()
    Component.onCompleted: reload()
  }

  Timer {
    interval: 400
    running: root.careEnabled
    repeat: true
    onTriggered: root.applyCareVisuals()
  }

  property real revertDeadline: 0

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/im0001gt.screens/profiles.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text() || "{}")
        var pending = data.pendingRevert
        root.revertDeadline = pending && pending.deadline ? Number(pending.deadline) : 0
      } catch (e) {
        root.revertDeadline = 0
      }
    }
    onFileChanged: reload()
    onLoadFailed: root.revertDeadline = 0
    Component.onCompleted: reload()
  }

  Process {
    id: revertWatchProc
    command: [root.ctl, "revert-if-due"]
    stdout: StdioCollector { waitForEnd: true }
  }

  Timer {
    interval: 1000
    running: root.revertDeadline > 0
    repeat: true
    onTriggered: {
      if (Date.now() / 1000 < root.revertDeadline) return
      if (!revertWatchProc.running) revertWatchProc.running = true
    }
  }
}
