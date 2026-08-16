import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "im0001gt.screens"
  ipcTarget: "im0001gt.screens"
  manageIpc: false

  readonly property string ctl:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/" + root.moduleName + "/scripts/display-ctl"

  property var monitors: []
  property int selectedIndex: 0
  property bool applying: false
  property bool dragging: false
  property int dragIndex: -1
  property real dragOrigX: 0
  property real dragOrigY: 0
  property real dragGrabX: 0
  property real dragGrabY: 0
  property var guideX: null
  property var guideY: null
  property bool identifying: false
  property var profiles: []
  property string activeProfile: ""
  property bool autoSwitch: true
  property string matchProfile: ""
  property string connectedKey: ""
  property string lastKey: ""
  property string profileName: ""
  property bool namingProfile: false
  property string primaryId: ""
  property bool userPicked: false

  readonly property var selected: {
    if (selectedIndex < 0 || selectedIndex >= monitors.length) return null
    return monitors[selectedIndex]
  }
  readonly property int enabledCount: {
    var n = 0
    for (var i = 0; i < monitors.length; i++) if (monitors[i].enabled) n++
    return n
  }
  readonly property var scalePresets: ["1", "1.25", "1.5", "2"]
  readonly property var rotateOptions: [
    { value: "0", label: "Landscape" },
    { value: "1", label: "Portrait 90°" },
    { value: "2", label: "Upside down" },
    { value: "3", label: "Portrait 270°" }
  ]
  // Hyprland misc.vrr / per-output vrr: 0 off, 1 on, 2 fullscreen,
  // 3 fullscreen when the content type is video or game.
  readonly property var vrrOptions: [
    { value: "0", label: "Off" },
    { value: "1", label: "Always" },
    { value: "2", label: "Fullscreen" },
    { value: "3", label: "Games & video" }
  ]
  readonly property string barScreenName: {
    var win = button.QsWindow ? button.QsWindow.window : null
    return (win && win.screen) ? String(win.screen.name) : ""
  }
  readonly property bool isFocusedBar: {
    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].focused && monitors[i].name === barScreenName) return true
    }
    return false
  }
  readonly property bool selectedHdrOk: !!(selected && selected.hdrCapable)
  readonly property bool selectedVrrOk: !!(selected && selected.vrrCapable)
  readonly property var identifyScreen: {
    var name = selected ? selected.name : ""
    var screens = Quickshell.screens
    if (!name || !screens) return null
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === name) return screens[i]
    }
    return null
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function adopt(data) {
    var list = (data && data.monitors) ? Model.clone(data.monitors) : []
    root.monitors = list
    root.profiles = (data && data.profiles) ? data.profiles : []
    root.activeProfile = (data && data.active) ? String(data.active) : ""
    root.autoSwitch = !data || data.autoSwitch !== false
    root.matchProfile = (data && data.match) ? String(data.match) : ""
    root.primaryId = (data && data.primary) ? String(data.primary) : ""
    if (root.activeProfile && !root.namingProfile) root.profileName = root.activeProfile
    if (!root.userPicked) {
      var pick = Model.preferredIndex(list, root.barScreenName, root.primaryId)
      if (pick >= 0) root.selectedIndex = pick
    } else if (root.selectedIndex >= list.length) {
      root.selectedIndex = Math.max(0, list.length - 1)
    }
    var key = (data && data.connectedKey) ? String(data.connectedKey) : ""
    var prev = root.lastKey
    if (key) root.lastKey = key
    if (prev !== "" && key !== "" && prev !== key && root.autoSwitch && root.matchProfile
        && !root.opened && !root.dragging && !root.applying) {
      root.applyProfile(root.matchProfile)
    }
  }

  function selectByName(name) {
    var i = Model.indexByName(root.monitors, name)
    if (i >= 0) root.selectedIndex = i
  }

  function mutateSelected(fn) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    fn(next[root.selectedIndex], next)
    root.monitors = next
    applyNow()
  }

  function applyNow() {
    if (applyProc.running) {
      root.applying = true
      return
    }
    var payload = JSON.stringify(Model.applyPayload(Model.normalizeOrigin(Model.clone(root.monitors))))
    applyProc.command = [root.ctl, "apply", payload]
    root.applying = true
    applyProc.running = true
  }

  function setMode(mode) {
    mutateSelected(function(m) { m.mode = mode })
  }

  function setResolution(res) {
    mutateSelected(function(m) {
      var hz = parseFloat(String(m.mode || "").split("@")[1])
      m.mode = Model.pickMode(m, res, hz)
    })
  }

  function setScale(scale) {
    mutateSelected(function(m) { m.scale = Number(scale) })
  }

  function setTransform(value) {
    mutateSelected(function(m) { m.transform = parseInt(value, 10) || 0 })
  }

  function setVrr(value) {
    if (!root.selectedVrrOk) return
    var n = parseInt(value, 10)
    if (!isFinite(n) || n < 0) n = 0
    if (n > 3) n = 3
    mutateSelected(function(m) { m.vrr = n })
  }

  function setHdr(on) {
    if (!root.selectedHdrOk) return
    mutateSelected(function(m) { m.hdr = !!on })
  }

  function setEnabled(on) {
    if (!on && root.enabledCount <= 1) return
    mutateSelected(function(m) { m.enabled = !!on })
  }

  function setMirror(name) {
    mutateSelected(function(m) { m.mirror = name || "" })
  }

  function runStore(args) {
    if (storeProc.running) return
    storeProc.command = [root.ctl].concat(args)
    storeProc.running = true
  }

  function beginSave() {
    root.namingProfile = true
    if (!root.profileName) root.profileName = root.activeProfile
    Qt.callLater(function() {
      if (profileNameField) profileNameField.forceActiveFocus()
    })
  }

  function cancelSave() {
    root.namingProfile = false
    if (root.activeProfile) root.profileName = root.activeProfile
  }

  function saveProfile() {
    var name = String(root.profileName || "").trim()
    if (!name) {
      root.beginSave()
      return
    }
    root.profileName = name
    root.namingProfile = false
    var payload = JSON.stringify(Model.applyPayload(Model.normalizeOrigin(Model.clone(root.monitors))))
    root.runStore(["profile", "save", name, payload])
  }

  function deleteProfile() {
    var name = String(root.profileName || root.activeProfile || "").trim()
    if (!name) return
    root.runStore(["profile", "delete", name])
  }

  function applyProfile(name) {
    if (!name) return
    root.profileName = name
    if (applyProc.running) return
    applyProc.command = [root.ctl, "profile", "apply", name]
    root.applying = true
    applyProc.running = true
  }

  function setAutoSwitch(on) {
    root.autoSwitch = !!on
    root.runStore(["profile", "auto", on ? "1" : "0"])
  }

  function setPrimary() {
    if (!root.selected) return
    root.userPicked = true
    root.runStore(["profile", "primary", root.selected.identity || ""])
  }

  function identify() {
    if (!root.selected) return
    root.identifying = true
    identifyTimer.restart()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: {
    if (!opened) return
    root.userPicked = false
    refresh()
  }

  IpcHandler {
    enabled: root.isFocusedBar
    target: "im0001gt.screens"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Timer {
    interval: root.opened ? 4000 : 2000
    running: !root.dragging && !root.applying
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: identifyTimer
    interval: 2200
    onTriggered: root.identifying = false
  }

  Process {
    id: stateProc
    command: [root.ctl, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.dragging) return
        try { root.adopt(JSON.parse(text)) }
        catch (e) {}
      }
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applying = false
        try { root.adopt(JSON.parse(text)) }
        catch (e) { root.refresh() }
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.applying = false
        root.refresh()
      }
    }
  }

  Process {
    id: storeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.adopt(JSON.parse(text)) }
        catch (e) { root.refresh() }
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰕴"
    iconComponent: Component {
      ScreenMark {
        implicitWidth: button.fontSize
        implicitHeight: button.fontSize
        foreground: button.foreground
      }
    }
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, identifyBtn.implicitHeight)

            ScreenMark {
              id: heroIcon
              implicitWidth: Style.font.display
              implicitHeight: Style.font.display
              foreground: root.bar.foreground
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: identifyBtn.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Screens"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: (root.dragging ? "Snapping edges" : Model.heroStatus(root.selected, root.activeProfile)).toUpperCase()
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: Style.font.caption * 0.12
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Button {
              id: identifyBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Find"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: root.identify()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "PROFILE"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: Style.font.caption * 0.1
              }

              Dropdown {
                visible: !root.namingProfile && root.profiles.length > 1
                width: Style.space(168)
                showLabel: false
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                value: root.activeProfile
                options: Model.profileOptions(root.profiles)
                onChanged: function(v) { if (v && v !== root.activeProfile) root.applyProfile(v) }
              }

              Button {
                visible: !root.namingProfile && root.profiles.length === 1
                text: root.activeProfile || root.profiles[0].name
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                active: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
              }

              Button {
                visible: !root.namingProfile
                text: "Save"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                onClicked: root.beginSave()
              }

              Button {
                visible: !root.namingProfile && root.profiles.length > 0
                text: "Delete"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                onClicked: root.deleteProfile()
              }

              Button {
                visible: !root.namingProfile
                text: root.autoSwitch ? "On connect" : "Manual"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                active: root.autoSwitch
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                tooltipText: root.autoSwitch
                  ? "On: restore the matching saved layout when a display is plugged in"
                  : "Off: leave the layout alone when a display is plugged in"
                onClicked: root.setAutoSwitch(!root.autoSwitch)
              }
            }

            Row {
              visible: root.namingProfile
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: profileNameField
                width: parent.width - saveConfirmBtn.width - saveCancelBtn.width - parent.spacing * 2
                text: root.profileName
                placeholderText: "Name this layout"
                font.pixelSize: Style.font.body
                foreground: root.bar.foreground
                verticalPadding: Style.space(4)
                onTextChanged: if (activeFocus) root.profileName = text
                onAccepted: root.saveProfile()
                Keys.onEscapePressed: root.cancelSave()
              }

              Button {
                id: saveConfirmBtn
                text: "Save"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                onClicked: root.saveProfile()
              }

              Button {
                id: saveCancelBtn
                text: "Cancel"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                onClicked: root.cancelSave()
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              id: canvas
              width: parent.width
              implicitHeight: Style.space(168)

              readonly property int pad: Style.space(16)
              readonly property var box: Model.bounds(root.monitors)
              readonly property real fit: {
                var aw = Math.max(1, width - pad * 2)
                var ah = Math.max(1, height - pad * 2)
                return Math.min(aw / box.w, ah / box.h)
              }
              function cx(x) { return pad + (x - box.x) * fit }
              function cy(y) { return pad + (y - box.y) * fit }
              function cw(w) { return Math.max(Style.space(36), w * fit) }
              function ch(h) { return Math.max(Style.space(24), h * fit) }

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: Util.alpha(root.bar.foreground, 0.06)
                border.width: 1
                border.color: Util.alpha(root.bar.foreground, 0.16)
              }

              Repeater {
                model: root.monitors

                Rectangle {
                  required property var modelData
                  required property int index
                  visible: modelData.enabled
                  x: canvas.cx(modelData.x)
                  y: canvas.cy(modelData.y)
                  width: canvas.cw(modelData.logicalW)
                  height: canvas.ch(modelData.logicalH)
                  radius: Math.max(2, Style.cornerRadius)
                  color: {
                    if (root.identifying && index === root.selectedIndex)
                      return Util.alpha(Color.accent, 0.35)
                    if (index === root.selectedIndex)
                      return Util.alpha(Color.accent, 0.18)
                    return Util.alpha(root.bar.foreground, 0.08)
                  }
                  border.width: index === root.selectedIndex ? 2 : 1
                  border.color: index === root.selectedIndex
                    ? Util.alpha(Color.accent, 0.95)
                    : Util.alpha(root.bar.foreground, 0.28)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)
                    width: parent.width - Style.space(8)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: String(index + 1)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.label
                      color: Qt.darker(root.bar.foreground, 1.25)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }
              }

              Rectangle {
                visible: root.guideX !== null && root.guideX !== undefined
                x: canvas.cx(Number(root.guideX)) - 0.5
                y: canvas.pad
                width: 1
                height: canvas.height - canvas.pad * 2
                color: Color.accent
                opacity: 0.85
              }

              Rectangle {
                visible: root.guideY !== null && root.guideY !== undefined
                x: canvas.pad
                y: canvas.cy(Number(root.guideY)) - 0.5
                width: canvas.width - canvas.pad * 2
                height: 1
                color: Color.accent
                opacity: 0.85
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true

                function hit(mx, my) {
                  for (var i = root.monitors.length - 1; i >= 0; i--) {
                    var m = root.monitors[i]
                    if (!m.enabled) continue
                    var rx = canvas.cx(m.x), ry = canvas.cy(m.y)
                    var rw = canvas.cw(m.logicalW), rh = canvas.ch(m.logicalH)
                    if (mx >= rx && mx <= rx + rw && my >= ry && my <= ry + rh) return i
                  }
                  return -1
                }

                onPressed: function(mouse) {
                  var i = hit(mouse.x, mouse.y)
                  if (i < 0) return
                  root.selectedIndex = i
                  root.userPicked = true
                  root.dragging = true
                  root.dragIndex = i
                  root.dragOrigX = root.monitors[i].x
                  root.dragOrigY = root.monitors[i].y
                  root.dragGrabX = mouse.x
                  root.dragGrabY = mouse.y
                }

                onPositionChanged: function(mouse) {
                  if (!root.dragging || root.dragIndex < 0) return
                  var nx = root.dragOrigX + (mouse.x - root.dragGrabX) / canvas.fit
                  var ny = root.dragOrigY + (mouse.y - root.dragGrabY) / canvas.fit
                  var snapped = Model.snapMove(root.monitors, root.dragIndex, nx, ny, 96)
                  var next = Model.clone(root.monitors)
                  next[root.dragIndex].x = snapped.x
                  next[root.dragIndex].y = snapped.y
                  root.guideX = snapped.guideX
                  root.guideY = snapped.guideY
                  root.monitors = next
                }

                onReleased: {
                  if (!root.dragging) return
                  root.dragging = false
                  root.dragIndex = -1
                  root.guideX = null
                  root.guideY = null
                  root.monitors = Model.normalizeOrigin(Model.clone(root.monitors))
                  root.applyNow()
                }
              }
            }

          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.selected !== null

            Item {
              width: parent.width
              implicitHeight: Math.max(selHeader.implicitHeight, selName.implicitHeight)

              PanelSectionHeader {
                id: selHeader
                text: root.selected ? root.selected.label : "THIS SCREEN"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: selName
                text: root.selected ? root.selected.name : ""
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "RESOLUTION"
                showLabel: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                value: root.selected ? Model.resolutionOf(root.selected.mode) : ""
                options: root.selected ? Model.resolutionOptions(root.selected) : []
                onChanged: function(v) { root.setResolution(v) }
              }

              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "REFRESH RATE"
                showLabel: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                value: root.selected ? root.selected.mode : ""
                options: root.selected ? Model.refreshOptions(root.selected) : []
                onChanged: function(v) { root.setMode(v) }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              PanelSectionHeader {
                text: "SCALE"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }

              Grid {
                id: scaleRow
                width: parent.width
                columns: root.scalePresets.length
                spacing: Style.spacing.xs
                readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                Repeater {
                  model: root.scalePresets

                  Button {
                    required property string modelData
                    width: scaleRow.cellWidth
                    text: Number(modelData).toString() + "×"
                    fontSize: Style.font.caption
                    fontFamily: root.bar.fontFamily
                    foreground: root.bar.foreground
                    bordered: true
                    active: root.selected && Math.abs(Number(root.selected.scale) - Number(modelData)) < 0.01
                    onClicked: root.setScale(modelData)
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "ORIENTATION"
                showLabel: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                value: root.selected ? String(root.selected.transform) : "0"
                options: root.rotateOptions
                onChanged: function(v) { root.setTransform(v) }
              }

              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "MIRROR"
                showLabel: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                value: root.selected ? String(root.selected.mirror || "") : ""
                options: Model.mirrorOptions(root.monitors, root.selected)
                onChanged: function(v) { root.setMirror(v) }
              }
            }

            Toggle {
              visible: root.selectedHdrOk
              width: parent.width
              label: "HDR"
              description: "10-bit PQ"
              checked: !!(root.selected && root.selected.hdr)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.setHdr(!(root.selected && root.selected.hdr))
            }

            Dropdown {
              visible: root.selectedVrrOk
              width: parent.width
              label: "VRR"
              showLabel: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              value: root.selected ? String(root.selected.vrr || 0) : "0"
              options: root.vrrOptions
              onChanged: function(v) { root.setVrr(v) }
            }

            Text {
              visible: !root.selectedHdrOk || !root.selectedVrrOk
              width: parent.width
              text: {
                if (!root.selectedHdrOk && !root.selectedVrrOk)
                  return "HDR / VRR unavailable for this display"
                if (!root.selectedHdrOk)
                  return "HDR unavailable for this display"
                return "VRR unavailable for this display"
              }
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Toggle {
              width: parent.width
              label: "Enable this Display"
              description: root.enabledCount <= 1 && root.selected && root.selected.enabled
                ? "Keep at least one screen on"
                : "Include this screen in the layout"
              checked: !!(root.selected && root.selected.enabled)
              enabled: !(root.enabledCount <= 1 && root.selected && root.selected.enabled)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.setEnabled(!(root.selected && root.selected.enabled))
            }

            Button {
              width: parent.width
              text: root.selected && root.selected.identity === root.primaryId
                ? "Primary display"
                : "Make primary"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              active: !!(root.selected && root.selected.identity === root.primaryId)
              onClicked: root.setPrimary()
            }
          }

          Item { width: parent.width; height: Style.space(8) }
        }
      }
    }

  PanelWindow {
    id: identWin
    visible: root.identifying && !!root.identifyScreen
    screen: root.identifyScreen || (Quickshell.screens.length ? Quickshell.screens[0] : null)
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "im0001gt.screens-identify"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    BorderSurface {
      anchors.centerIn: parent
      implicitWidth: identCol.implicitWidth + Style.space(48)
      implicitHeight: identCol.implicitHeight + Style.space(36)
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      Column {
        id: identCol
        anchors.centerIn: parent
        spacing: Style.space(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: String(root.selectedIndex + 1)
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.displayLarge
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.selected ? root.selected.label : ""
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.selected ? root.selected.name : ""
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
