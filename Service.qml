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
  property bool panelWanted: false
  property bool panelMapped: false
  property string panelScreen: ""
  property bool pendingConfirm: false
  property int revertLeft: 0

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
    var host = Model.findHostBar(root)
    if (!host && root.bar && root.bar.moduleSlots) host = root.bar
    Model.applyBarCare(host, root.careConfig, {
      hovered: root.barHovered,
      barHidden: root.barHidden
    })
  }

  readonly property int hyprMonitorCount: {
    var vals = Hyprland.monitors && Hyprland.monitors.values
    return vals ? vals.length : 0
  }
  property int recoverTries: 0

  function requestRecover() {
    root.recoverTries = 0
    recoverRetry.restart()
    if (!recoverProc.running) recoverProc.running = true
  }

  Component.onCompleted: {
    if (!claimProc.running) claimProc.running = true
    Qt.callLater(root.applyCareVisuals)
    Qt.callLater(root.requestRecover)
  }
  onHyprMonitorCountChanged: root.requestRecover()
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

  Timer {
    id: recoverRetry
    interval: 800
    repeat: true
    onTriggered: {
      root.recoverTries += 1
      if (root.recoverTries >= 8) {
        running = false
        return
      }
      if (!recoverProc.running) recoverProc.running = true
    }
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



  property real revertDeadline: 0

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/im0001gt.screens/panel.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var data = JSON.parse(text() || "{}")
        root.panelWanted = !!data.wanted
        root.pendingConfirm = !!data.pendingConfirm
        root.panelScreen = String(data.screen || "")
        if (!root.panelWanted) root.panelMapped = false
      } catch (e) {}
    }
    onFileChanged: reload()
    onLoadFailed: {
      if (root.panelWanted || root.pendingConfirm) return
      root.panelWanted = false
      root.pendingConfirm = false
      root.panelScreen = ""
      root.panelMapped = false
    }
    Component.onCompleted: reload()
  }

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
