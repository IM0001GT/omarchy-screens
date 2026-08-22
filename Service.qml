import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var barWidgetRegistry: null
  property var manifest: null
  property var shell: null
  property var component: null
  readonly property string ctl:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/im0001gt.screens/scripts/display-ctl"

  Component.onCompleted: {
    registerWidget()
    if (!claimProc.running) claimProc.running = true
  }
  onBarWidgetRegistryChanged: registerWidget()

  Process {
    id: claimProc
    command: [root.ctl, "claim"]
    stdout: StdioCollector { waitForEnd: true }
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
