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

  property var assignment: ({ enabled: false, monitors: [], layouts: {}, labels: {} })
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

  readonly property int activeWorkspaceId: {
    var name = root.barScreenName
    var mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : []
    var i, aw, ipc, id
    for (i = 0; i < mons.length; i++) {
      if (String(mons[i].name || "") !== name) continue
      aw = mons[i].activeWorkspace
      if (aw && typeof aw.id === "number") return aw.id
      ipc = mons[i].lastIpcObject
      if (ipc && ipc.activeWorkspace && ipc.activeWorkspace.id)
        return Number(ipc.activeWorkspace.id) || 0
    }
    var fw = Hyprland.focusedWorkspace
    if (fw && root.workspaceMonitorName(fw) === name) return fw.id
    var ids = root.workspaceIds()
    for (i = 0; i < ids.length; i++) {
      var ws = root.workspaceById(ids[i])
      if (ws && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === ids[i])
        return ids[i]
    }
    return ids.length ? ids[0] : 0
  }

  readonly property string activeWorkspaceName: {
    var lab = Model.workspaceLabelOf(root.assignment, root.activeWorkspaceId)
    var name = String(lab.name || "").trim()
    if (name.length > 18) return name.slice(0, 17) + "…"
    return name
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

  function setWorkspaceLabel(name, icon) {
    var n = Model.workspaceId(root.menuWorkspace)
    if (!n) return
    labelProc.command = [
      Quickshell.env("HOME") + "/.config/omarchy/plugins/im0001gt.screens/scripts/display-ctl",
      "workspace-label",
      String(n),
      String(name || ""),
      String(icon || "")
    ]
    if (!labelProc.running) labelProc.running = true
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

  readonly property bool rowHasIcon: {
    var ids = root.workspaceIds()
    for (var i = 0; i < ids.length; i++) {
      if (Model.workspaceLabelOf(root.assignment, ids[i]).icon) return true
    }
    return false
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
    onLoadFailed: root.assignment = ({ enabled: false, monitors: [], layouts: {}, labels: {} })
    Component.onCompleted: reload()
  }

  Process {
    id: layoutProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: labelProc
    stdout: StdioCollector { waitForEnd: true }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length + (root.activeWorkspaceName !== "" ? 1 : 0))
    columnSpacing: root.vertical ? 0 : Style.space(root.rowHasIcon ? 4 : 1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: Model.workspaceBarText(root.assignment, modelData, focused)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: root.rowHasIcon ? 8 : 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(root.rowHasIcon ? 24 : 20)
        fixedHeight: root.barSize
        tooltipText: {
          var lab = Model.workspaceLabelOf(root.assignment, modelData)
          var bits = ["Left: go there", "Right: name, icon, layout"]
          if (lab.name) bits.unshift(lab.name)
          return bits.join(" · ")
        }
        onPressed: function(button) {
          if (button === Qt.RightButton) {
            root.openLayoutMenu(modelData, this)
            return
          }
          if (root.menuOpen) root.menuOpen = false
          root.focusWorkspace(modelData)
        }
      }
    }

    Loader {
      active: root.activeWorkspaceName !== ""
      sourceComponent: nameChip
      Layout.preferredWidth: item ? item.implicitWidth : 0
      Layout.preferredHeight: item ? item.implicitHeight : 0
    }
  }

  Component {
    id: nameChip
    WidgetButton {
      bar: root.bar
      text: root.activeWorkspaceName
      opacity: 1
      horizontalMargin: 10
      verticalPadding: 6
      fixedHeight: root.barSize
      tooltipText: "Workspace " + Model.workspaceDigit(root.activeWorkspaceId)
      onPressed: function(button) {
        root.openLayoutMenu(root.activeWorkspaceId, this)
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
    id: workspaceMenu
    anchorItem: root.menuAnchor || dummyAnchor
    bar: root.bar
    owner: menuOwner
    open: root.menuOpen && !!root.menuAnchor
    workspaceId: root.menuWorkspace
    currentLayout: root.layoutOf(root.menuWorkspace)
    workspaceName: Model.workspaceLabelOf(root.assignment, root.menuWorkspace).name
    workspaceIcon: Model.workspaceLabelOf(root.assignment, root.menuWorkspace).icon
    onChosen: function(mode) { root.setWorkspaceLayout(mode) }
    onLabeled: function(name, icon) { root.setWorkspaceLabel(name, icon) }
  }
}
