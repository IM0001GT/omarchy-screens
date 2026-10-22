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

  property var assignment: ({ enabled: false, labels: {} })
  property var blocks: ({})
  property var workspaceIdCache: ({ ids: [] })
  property int menuWorkspace: 0
  property var menuAnchor: null
  property bool menuOpen: false
  property string activeMode: "dwindle"
  property bool modeStale: false
  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0
  property real wheelAccumulator: 0

  readonly property int slots: 10
  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? String(root.monitor.name || "") : ""
  readonly property int block: {
    var known = root.blocks[root.monitorName]
    if (known !== undefined) return known
    var active = root.activeWorkspaceId
    return active > 0 ? Model.workspaceBlock(active) : 0
  }
  readonly property int activeWorkspaceId: {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }
  readonly property string activeWorkspaceName: {
    var name = Model.workspaceLabelOf(root.assignment, root.activeWorkspaceId).name
    if (name.length > 18) return name.slice(0, 17) + "…"
    return name
  }

  function readLabels(text) {
    var raw = String(text || "")
    if (!raw || raw.length > 65536) {
      root.assignment = Model.normalizeWorkspaceLabels(null)
      return
    }
    try {
      root.assignment = Model.normalizeWorkspaceLabels(JSON.parse(raw))
    } catch (e) {
      root.assignment = Model.normalizeWorkspaceLabels(null)
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // First five of this monitor's block, then any of 6-10 that exist, then
  // guests parked here from an unplugged screen.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (!Model.workspaceId(id)) continue
      if (Model.workspaceBlock(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }
    ids.sort(function(a, b) { return a - b })
    guests.sort(function(a, b) { return a - b })
    return ids.concat(guests)
  }

  function sameWorkspaceIds(prev, next) {
    if (!prev || prev.length !== next.length) return false
    for (var i = 0; i < next.length; i++) {
      if (prev[i] !== next[i]) return false
    }
    return true
  }

  function workspaceIdsForBar() {
    var next = root.workspaceIds()
    var cache = root.workspaceIdCache
    var prev = cache && cache.ids
    if (root.sameWorkspaceIds(prev, next)) return prev
    if (cache) cache.ids = next
    return next
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    var n = Model.workspaceId(id)
    if (!n) return
    if (Model.workspaceBlock(n) === root.block) {
      var mon = Model.safeConnector(root.monitorName)
      var slot = Model.workspaceSlot(n)
      if (mon && slot)
        root.dispatch('o.workspaces.focus(' + slot + ', "' + mon + '")')
      else
        root.dispatch('hl.dsp.focus({ workspace = "' + n + '" })')
    } else {
      root.dispatch('hl.dsp.focus({ workspace = "' + n + '" })')
    }
  }

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId)
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  function modeGlyph(mode) {
    if (mode === "scrolling") return "󰝥"
    if (mode === "floating") return "󰔶"
    return "󱓻"
  }

  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId]
    if (mode !== undefined) root.activeMode = mode
    else root.readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.activeWorkspaceId
    if (!Model.workspaceId(id)) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }

  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    root.readMode()
  }

  function cycleLayout() {
    if (!root.bar) return
    var command = "omarchy-hyprland-workspace-layout-toggle"
    var mon = Model.safeConnector(root.monitorName)
    if (root.monitor && !root.monitor.focused && mon) {
      command = "hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ monitor = "' + mon + '" })') + " >/dev/null && " + command
    }
    root.bar.run(command)
  }

  function openLabelMenu(id, anchor) {
    var n = Model.workspaceId(id)
    if (!n) return
    root.menuWorkspace = n
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
      Model.cleanWorkspaceName(name),
      Model.presetIcon(icon)
    ]
    if (!labelProc.running) labelProc.running = true
  }

  function pillText(id, shown) {
    var icon = Model.workspaceLabelOf(root.assignment, id).icon
    if (icon) return icon
    if (shown) return root.modeGlyph(root.activeMode)
    return Model.workspaceBarText(root.assignment, id, false)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onLoaded: root.blocks = Model.monitorBlocks(text())
    onFileChanged: reload()
    onLoadFailed: root.blocks = ({})
    Component.onCompleted: reload()
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/im0001gt.screens/workspaces.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.readLabels(text())
    onFileChanged: reload()
    onLoadFailed: root.assignment = Model.normalizeWorkspaceLabels(null)
    Component.onCompleted: reload()
  }

  Process {
    id: labelProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      Qt.callLater(root.showActiveMode)
    }
  }

  ShellIpc {
    target: "im0001gt.screens.workspaces"
    function refresh(): void { root.refresh() }
  }

  Component.onCompleted: root.refresh()
  onMonitorChanged: root.showActiveMode()

  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length + (root.activeWorkspaceName !== "" ? 1 : 0))
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIdsForBar()

      WidgetButton {
        id: cell
        required property int modelData
        required property int index

        readonly property bool occupied: {
          var workspace = root.workspaceById(modelData)
          return workspace !== null && workspace.toplevels.values.length > 0
        }
        readonly property bool shown: root.activeWorkspaceId === modelData
        readonly property bool firstGuest: Model.workspaceBlock(modelData) !== root.block
          && index > 0
          && Model.workspaceBlock(root.workspaceIds()[index - 1]) === root.block
        readonly property string tipName: Model.workspaceLabelOf(root.assignment, modelData).name

        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        bar: root.bar
        text: root.pillText(modelData, shown)
        opacity: occupied || shown ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        tooltipText: {
          var bits = []
          if (tipName) bits.push(tipName)
          bits.push(shown ? "Left: change layout" : "Left: go there")
          bits.push("Right: name and icon")
          return bits.join(" · ")
        }
        onPressed: function(button) {
          if (button === Qt.RightButton) {
            root.openLabelMenu(modelData, cell)
            return
          }
          if (root.menuOpen) root.menuOpen = false
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }
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
      tooltipText: "Workspace " + Model.workspaceBarText(root.assignment, root.activeWorkspaceId, false)
      onPressed: function(button) {
        root.openLabelMenu(root.activeWorkspaceId, this)
      }
    }
  }

  QtObject {
    id: menuOwner
    function close() { root.menuOpen = false }
  }

  Loader {
    active: root.menuOpen && !!root.menuAnchor
    sourceComponent: Component {
      WorkspaceLayoutMenu {
        anchorItem: root.menuAnchor
        bar: root.bar
        owner: menuOwner
        open: true
        workspaceId: root.menuWorkspace
        workspaceName: Model.workspaceLabelOf(root.assignment, root.menuWorkspace).name
        workspaceIcon: Model.workspaceLabelOf(root.assignment, root.menuWorkspace).icon
        onLabeled: function(name, icon) { root.setWorkspaceLabel(name, icon) }
      }
    }
  }
}
