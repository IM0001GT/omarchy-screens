import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  property var barWidgetRegistry: null
  property var manifest: null
  property var shell: null
  property var component: null
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

  Component.onCompleted: {
    registerWidget()
    if (!claimProc.running) claimProc.running = true
    Qt.callLater(root.applyCareVisuals)
  }
  onBarWidgetRegistryChanged: registerWidget()
  onCareConfigChanged: root.applyCareVisuals()
  onBarHoveredChanged: root.applyCareVisuals()
  onBarHiddenChanged: root.applyCareVisuals()
  onBarChanged: root.applyCareVisuals()

  Process {
    id: claimProc
    command: [root.ctl, "claim"]
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

  function registerWidget() {
    if (!root.barWidgetRegistry) return
    var url = Qt.resolvedUrl("Workspaces.qml")
    var comp = Qt.createComponent(url, Component.PreferSynchronous)
    if (comp.status === Component.Loading) {
      comp.statusChanged.connect(function() { root.finishRegister(comp) })
      return
    }
    root.finishRegister(comp)
  }

  function finishRegister(comp) {
    if (!comp || comp.status !== Component.Ready) {
      console.warn("im0001gt.screens: workspaces widget failed to load"
        + (comp ? (": " + comp.errorString()) : ""))
      return
    }
    root.component = comp
    root.barWidgetRegistry.register("im0001gt.screens.workspaces", comp, {
      displayName: "Screens workspaces",
      description: "Per-display workspaces. Right-click to name, pick an icon, or set Tile / Scroll / Float.",
      category: "Compositor",
      allowMultiple: false,
      pluginId: "im0001gt.screens",
      source: "plugin"
    })
  }
}
