import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "im0001gt.screens.workspaces"

  property var assignment: ({ enabled: false, monitors: [], layouts: {} })
  property int menuWorkspace: 0
  property var menuAnchor: null
  property bool menuOpen: false

  readonly property string barScreenName: {
    var win = root.QsWindow ? root.QsWindow.window : null
    return (win && win.screen) ? String(win.screen.name) : ""
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceMonitorName(ws) {
    if (!ws) return ""
    if (ws.monitor) {
      if (typeof ws.monitor === "string") return String(ws.monitor)
      if (ws.monitor.name) return String(ws.monitor.name)
    }
    var ipc = ws.lastIpcObject
    if (ipc && ipc.monitor) return String(ipc.monitor)
    return ""
  }

  function workspaceIds() {
    var mons = (root.assignment && root.assignment.monitors) ? root.assignment.monitors : []
    var i
    if (root.assignment && root.assignment.enabled) {
      for (i = 0; i < mons.length; i++) {
        if (mons[i] && mons[i].name === root.barScreenName)
          return mons[i].ids || []
      }
    }
    var ids = []
    var values = Hyprland.workspaces.values
    for (i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && root.workspaceMonitorName(values[i]) === root.barScreenName
          && ids.indexOf(id) === -1)
        ids.push(id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }

  function layoutOf(id) {
    var layouts = (root.assignment && root.assignment.layouts) ? root.assignment.layouts : {}
    return String(layouts[String(id)] || "tile")
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    var n = Model.workspaceId(id)
    if (!n) return
    root.bar.run("hyprctl eval " + Util.shellQuote("hl.dispatch(hl.dsp.focus({ workspace = \"" + n + "\" }))"))
  }

  function openLayoutMenu(id, anchor) {
    root.menuWorkspace = id
    root.menuAnchor = anchor
    root.menuOpen = true
  }

  function setWorkspaceLayout(mode) {
    root.menuOpen = false
    var n = Model.workspaceId(root.menuWorkspace)
    if (!n) return
    layoutProc.command = [
      Quickshell.env("HOME") + "/.config/omarchy/plugins/im0001gt.screens/scripts/display-ctl",
      "workspace-layout",
      String(n),
      mode
    ]
    if (!layoutProc.running) layoutProc.running = true
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/im0001gt.screens/workspaces.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.assignment = JSON.parse(text()) }
      catch (e) {}
    }
    onFileChanged: reload()
    onLoadFailed: root.assignment = ({ enabled: false, monitors: [], layouts: {} })
    Component.onCompleted: reload()
  }

  Process {
    id: layoutProc
    stdout: StdioCollector { waitForEnd: true }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : Model.workspaceDigit(modelData)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        tooltipText: "Left: go there · Right: Tile / Scroll / Float"
        onPressed: function(button) {
          if (button === Qt.RightButton) root.openLayoutMenu(modelData, this)
          else root.focusWorkspace(modelData)
        }
      }
    }
  }

  QtObject {
    id: menuOwner
    function close() { root.menuOpen = false }
  }

  Item {
    id: dummyAnchor
    width: 1
    height: 1
    visible: false
  }

  WorkspaceLayoutMenu {
    anchorItem: root.menuAnchor || dummyAnchor
    bar: root.bar
    owner: menuOwner
    open: root.menuOpen && !!root.menuAnchor
    workspaceId: root.menuWorkspace
    currentLayout: root.layoutOf(root.menuWorkspace)
    onChosen: function(mode) { root.setWorkspaceLayout(mode) }
  }
}
