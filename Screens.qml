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
  property bool detectPending: false
  property string detectNote: ""
  property string pendingProfile: ""
  property bool pendingIdentify: false
  property var standbyNames: []
  property bool hybridGpus: false
  property bool showHybridNotice: false
  property bool hdrTuning: false
  property int brightnessPercent: 0
  property int pendingBrightnessPercent: 0
  property bool brightnessSetQueued: false
  property bool brightnessAvailable: false
  property int textSizePreviewIndex: -1
  property bool reflowingText: false
  property bool lastDisplayBounce: false
  property int lastDisplayQuipIndex: 0
  property string lastDisplayQuip: ""
  readonly property var textSizeStops: [9, 10, 11, 12, 14, 16, 20]

  readonly property var selected: {
    if (selectedIndex < 0 || selectedIndex >= monitors.length) return null
    return monitors[selectedIndex]
  }
  readonly property int enabledCount: {
    var n = 0
    for (var i = 0; i < monitors.length; i++) if (monitors[i].enabled) n++
    return n
  }
  readonly property int disabledCount: Math.max(0, monitors.length - enabledCount)
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
  readonly property var bitdepthOptions: [
    { value: "8", label: "8-bit" },
    { value: "10", label: "10-bit" }
  ]
  readonly property var hdrCmOptions: [
    { value: "hdredid", label: "Display" },
    { value: "hdr", label: "Wide" }
  ]
  readonly property var hdrModeOptions: [
    { value: "0", label: "Off" },
    { value: "1", label: "Auto" },
    { value: "2", label: "Always" }
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
  readonly property bool selectedSecondaryGpu: !!(selected && selected.secondaryGpu)
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
    if (root.opened) root.refreshBrightness()
  }

  function brightnessMonitor() {
    if (root.selected && root.selected.name) return String(root.selected.name)
    return root.barScreenName
  }

  function refreshBrightness() {
    if (setBrightnessProc.running) return
    if (brightnessSlider && brightnessSlider.dragging) return
    var name = root.brightnessMonitor()
    if (!name) {
      root.brightnessAvailable = false
      return
    }
    brightnessProc.command = ["omarchy-brightness-display", "--monitor", name]
    if (!brightnessProc.running) brightnessProc.running = true
  }

  function setBrightness(value) {
    var percent = Model.clampBrightness(value)
    root.brightnessPercent = percent
    root.pendingBrightnessPercent = percent
    var name = root.brightnessMonitor()
    if (!name) return
    if (setBrightnessProc.running) {
      root.brightnessSetQueued = true
      return
    }
    root.brightnessSetQueued = false
    setBrightnessProc.command = ["omarchy-brightness-display", "--no-osd", "--monitor", name, percent + "%"]
    setBrightnessProc.running = true
  }

  function previewBrightness(value) {
    root.brightnessPercent = Model.clampBrightness(value)
    brightnessDebounce.restart()
  }

  function nearestTextStop(px) {
    var best = 0
    var bestDist = 1e9
    for (var i = 0; i < root.textSizeStops.length; i++) {
      var d = Math.abs(root.textSizeStops[i] - px)
      if (d < bestDist) { bestDist = d; best = i }
    }
    return best
  }

  function currentTextIndex() {
    return root.textSizePreviewIndex >= 0
      ? root.textSizePreviewIndex
      : root.nearestTextStop(Style.font.baseSize)
  }

  function displayedTextPx() {
    return root.textSizePreviewIndex >= 0
      ? root.textSizeStops[root.textSizePreviewIndex]
      : Style.font.baseSize
  }

  function setTextSize(px) {
    root.textSizePreviewIndex = root.nearestTextStop(px)
    textScaleProc.command = ["omarchy-display-text-size", String(px)]
    if (!textScaleProc.running) textScaleProc.running = true
  }

  function markReflowing() {
    root.reflowingText = true
    reflowSettle.restart()
  }

  function adopt(data) {
    var keepId = ""
    var keepName = ""
    if (root.userPicked && root.selected) {
      keepId = root.selected.identity || ""
      keepName = root.selected.name || ""
    }
    var list = (data && data.monitors) ? Model.clone(data.monitors) : []
    root.monitors = list
    root.profiles = (data && data.profiles) ? data.profiles : []
    root.activeProfile = (data && data.active) ? String(data.active) : ""
    root.autoSwitch = !data || data.autoSwitch !== false
    root.matchProfile = (data && data.match) ? String(data.match) : ""
    root.primaryId = (data && data.primary) ? String(data.primary) : ""
    root.hybridGpus = !!(data && data.hybridGpus)
    if (data && data.hybridNotice === false) root.showHybridNotice = false
    else if (root.opened && data && data.hybridNotice) root.showHybridNotice = true
    if (root.activeProfile && !root.namingProfile) root.profileName = root.activeProfile
    if (root.detectPending) {
      root.detectPending = false
      var off = -1
      for (var d = 0; d < list.length; d++) {
        if (list[d] && !list[d].enabled) { off = d; break }
      }
      if (off >= 0) {
        root.userPicked = true
        root.selectedIndex = off
        root.detectNote = "Found " + (list[off].label || list[off].name) + " — turn it on below"
        if (list[off].secondaryGpu)
          root.detectNote += ". If it stays blank, restart Hyprland or the machine."
      } else {
        root.detectNote = "No other displays found"
      }
    } else if (keepId || keepName) {
      var kept = keepId ? Model.indexByIdentity(list, keepId) : -1
      if (kept < 0 && keepName) kept = Model.indexByName(list, keepName)
      if (kept >= 0) root.selectedIndex = kept
      else if (root.selectedIndex >= list.length) root.selectedIndex = Math.max(0, list.length - 1)
    } else if (!root.userPicked) {
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
    Qt.callLater(function() { root.revealItem(scaleSection) })
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

  function setHdrMode(value) {
    if (!root.selectedHdrOk) return
    var n = parseInt(value, 10)
    if (n !== 1 && n !== 2) n = 0
    mutateSelected(function(m) {
      m.hdrMode = n
      m.hdr = n === 2
      if (n === 0) return
      var capable = Number(m.bitdepthCapable) === 8 ? 8 : 10
      if (Number(m.bitdepth) !== 8 && Number(m.bitdepth) !== 10)
        m.bitdepth = capable
      if (!m.wideGamut) m.cm = "hdredid"
      else if (m.cm !== "hdr" && m.cm !== "hdredid") m.cm = "hdr"
      if (m.sdrMinLuminance === undefined || m.sdrMinLuminance === null
          || Number(m.sdrMinLuminance) >= 0.199)
        m.sdrMinLuminance = 0.005
      if (!m.sdrMaxLuminance || Number(m.sdrMaxLuminance) <= 80)
        m.sdrMaxLuminance = Model.defaultSdrPeak(m)
      if (!m.sdrBrightness || Number(m.sdrBrightness) <= 1)
        m.sdrBrightness = Model.defaultSdrBrightness(m)
      if (m.minLuminance === undefined || Number(m.minLuminance) < 0)
        m.minLuminance = 0
    })
    if (n > 0) Qt.callLater(function() { root.revealItem(hdrTuneSection.visible ? hdrTuneSection : hdrRow) })
  }

  function setBitdepth(value) {
    if (!root.selectedHdrOk) return
    var n = parseInt(value, 10) === 8 ? 8 : 10
    mutateSelected(function(m) { m.bitdepth = n })
  }

  function setHdrCm(value) {
    if (!root.selectedHdrOk) return
    var cm = String(value) === "hdredid" ? "hdredid" : "hdr"
    mutateSelected(function(m) { m.cm = cm })
  }

  function setSdrMin(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrMinLuminance = Math.max(0, Math.min(0.2, Number(value)))
    root.monitors = next
    if (apply) applyNow()
  }

  function setSdrMax(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrMaxLuminance = Math.max(40, Math.min(400, Math.round(Number(value))))
    root.monitors = next
    if (apply) applyNow()
  }

  function setSdrBrightness(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrBrightness = Math.max(0.8, Math.min(2.0, Math.round(Number(value) * 20) / 20))
    root.monitors = next
    if (apply) applyNow()
  }

  function revealItem(item) {
    if (!item || !panelFlick) return
    if (panelFlick.contentHeight <= panelFlick.height) return
    var y = item.mapToItem(panelFlick.contentItem, 0, 0).y
    var h = item.height
    var top = panelFlick.contentY
    var bot = top + panelFlick.height
    var margin = Style.space(8)
    if (y < top + margin)
      panelFlick.contentY = Math.max(0, y - margin)
    else if (y + h > bot - margin)
      panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentHeight - panelFlick.height, y + h + margin - panelFlick.height))
  }

  function setEnabled(on) {
    if (!on && root.enabledCount <= 1) {
      root.lastDisplayBounce = true
      root.lastDisplayQuip = Model.lastDisplayQuip(root.lastDisplayQuipIndex)
      root.lastDisplayQuipIndex = root.lastDisplayQuipIndex + 1
      lastDisplayBounceTimer.restart()
      return
    }
    root.lastDisplayBounce = false
    root.lastDisplayQuip = ""
    root.userPicked = true
    if (!on && root.selectedSecondaryGpu) {
      root.detectNote = "If this panel stays blank after you turn it back on, restart Hyprland or the machine."
    }
    mutateSelected(function(m) { m.enabled = !!on })
  }

  function detect() {
    root.detectPending = true
    root.detectNote = "Looking for displays…"
    refresh()
  }

  function enableAt(index) {
    if (index < 0 || index >= root.monitors.length) return
    if (root.monitors[index].enabled) return
    root.userPicked = true
    root.selectedIndex = index
    root.detectNote = root.monitors[index].secondaryGpu
      ? "If this panel is listed but stays blank, restart Hyprland or the machine."
      : ""
    root.pendingIdentify = true
    var saved = root.matchProfile || root.activeProfile
    if (root.autoSwitch && saved) {
      applyProfile(saved)
      return
    }
    var next = Model.clone(root.monitors)
    next[index].enabled = true
    root.monitors = next
    applyNow()
  }

  function setMirror(name) {
    if (name) {
      mutateSelected(function(m) { m.mirror = name })
      return
    }
    var saved = root.activeProfile || root.matchProfile
    if (saved) {
      applyProfile(saved)
      return
    }
    if (applyProc.running) return
    applyProc.command = [root.ctl, "unmirror"]
    root.applying = true
    applyProc.running = true
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

  function firstProfileName() {
    if (root.activeProfile) return root.activeProfile
    var list = root.profiles
    if (!list || list.length < 1) return ""
    var p = list[0]
    return (p && p.name) ? p.name : ""
  }

  function deleteProfile() {
    var name = String(root.profileName || root.activeProfile || "").trim()
    if (!name) return
    root.runStore(["profile", "delete", name])
  }

  function applyProfile(name) {
    if (!name) return
    root.profileName = name
    if (applyProc.running) {
      root.pendingProfile = name
      return
    }
    applyProc.command = [root.ctl, "profile", "apply", name]
    root.applying = true
    applyProc.running = true
  }

  function setAutoSwitch(on) {
    root.autoSwitch = !!on
    root.runStore(["profile", "auto", on ? "1" : "0"])
  }

  function dismissHybridNotice() {
    root.showHybridNotice = false
    root.runStore(["idle", "notice"])
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

  function standbyOn(name) {
    var n = String(name || "")
    if (!n) return
    var next = []
    for (var i = 0; i < root.standbyNames.length; i++) {
      if (root.standbyNames[i] !== n) next.push(root.standbyNames[i])
    }
    next.push(n)
    root.standbyNames = next
  }

  function standbyOff() {
    root.standbyNames = []
  }

  function isStandbyScreen(name) {
    var n = String(name || "")
    for (var i = 0; i < root.standbyNames.length; i++) {
      if (root.standbyNames[i] === n) return true
    }
    return false
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: {
    if (!opened) {
      root.detectNote = ""
      root.detectPending = false
      root.hdrTuning = false
      return
    }
    root.userPicked = false
    root.lastDisplayBounce = false
    root.lastDisplayQuip = ""
    refresh()
  }

  onSelectedIndexChanged: if (root.opened) root.refreshBrightness()

  IpcHandler {
    enabled: root.isFocusedBar
    target: "im0001gt.screens"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function blank(name: string): void { root.standbyOn(name) }
    function unblank(): void { root.standbyOff() }
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

  Timer {
    id: lastDisplayBounceTimer
    interval: 220
    onTriggered: root.lastDisplayBounce = false
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
        if (root.pendingProfile) {
          var nextProfile = root.pendingProfile
          root.pendingProfile = ""
          root.applyProfile(nextProfile)
          return
        }
        if (root.pendingIdentify) {
          root.pendingIdentify = false
          root.identify()
        }
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

  Process {
    id: brightnessProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (brightnessSlider && brightnessSlider.dragging) return
        var line = String(text || "").trim().split("\n")[0]
        var n = parseInt(line, 10)
        root.brightnessAvailable = line !== "" && line !== "unavailable" && isFinite(n)
        if (root.brightnessAvailable) root.brightnessPercent = Math.max(0, Math.min(100, n))
      }
    }
  }

  Timer {
    id: brightnessDebounce
    interval: 180
    repeat: false
    onTriggered: root.setBrightness(root.brightnessPercent)
  }

  Process {
    id: setBrightnessProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      if (root.brightnessSetQueued) root.setBrightness(root.pendingBrightnessPercent)
    }
  }

  Process {
    id: textScaleProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Timer {
    id: reflowSettle
    interval: 300
    repeat: false
    onTriggered: root.reflowingText = false
  }

  Connections {
    target: Style
    function onFontBaseSizeChanged() {
      root.markReflowing()
      if (root.textSizePreviewIndex >= 0
          && root.nearestTextStop(Style.font.baseSize) === root.textSizePreviewIndex)
        root.textSizePreviewIndex = -1
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
      onMoveRequested: function(dx, dy) {
        if (!panelFlick.interactive) return
        var step = Style.space(48)
        var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
        panelFlick.contentY = Math.max(0, Math.min(maxY, panelFlick.contentY + dy * step))
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height && !root.dragging

        Column {
          id: panelColumn
          width: panelFlick.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

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
              anchors.right: heroActions.left
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
                text: (root.dragging ? "Snapping edges"
                  : (brightnessSlider && brightnessSlider.dragging)
                    ? Model.brightnessName(brightnessSlider.liveValue)
                  : root.detectNote ? root.detectNote
                  : Model.heroStatus(root.selected, root.activeProfile)).toUpperCase()
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: Style.font.caption * 0.12
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Row {
              id: heroActions
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Button {
                text: "Detect"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(4)
                onClicked: root.detect()
              }

              Button {
                id: identifyBtn
                text: "Find"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(4)
                enabled: !!(root.selected && root.selected.enabled && root.identifyScreen)
                onClicked: root.identify()
              }
            }
          }

          Column {
            visible: root.showHybridNotice
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Displays are on more than one GPU. Hyprland can leave any panel on a non-primary GPU blank after standby or after you disable it, until you restart Hyprland or the machine. Idle sleep only the primary GPU's panel; other GPUs stay on but black. Detect can find a disabled output — if Turn on lists it but the picture never appears, reboot Hyprland or the system."
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              text: "Got it"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: root.dismissHybridNotice()
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
                onChanged: function(v) { if (v) root.applyProfile(v) }
              }

              Button {
                visible: !root.namingProfile && root.profiles.length === 1
                text: root.firstProfileName()
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                active: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                tooltipText: "Apply this saved layout"
                onClicked: root.applyProfile(root.firstProfileName())
              }

              Button {
                visible: !root.namingProfile && root.profiles.length > 1 && !!root.activeProfile
                text: "Apply"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(3)
                tooltipText: "Apply the selected layout"
                onClicked: root.applyProfile(root.activeProfile)
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
            visible: root.disabledCount > 0 || root.detectNote !== ""

            Repeater {
              model: root.monitors.length

              Item {
                required property int index
                readonly property var mon: root.monitors[index]
                visible: !!(mon && !mon.enabled)
                width: parent.width
                implicitHeight: visible ? Math.max(offLabel.implicitHeight, offBtn.implicitHeight) : 0

                Text {
                  id: offLabel
                  anchors.left: parent.left
                  anchors.right: offBtn.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: (mon ? (mon.label || mon.name) : "") + " · Off"
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Button {
                  id: offBtn
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Turn on"
                  fontSize: Style.font.caption
                  fontFamily: root.bar.fontFamily
                  foreground: root.bar.foreground
                  bordered: true
                  horizontalPadding: Style.space(10)
                  verticalPadding: Style.space(3)
                  onClicked: root.enableAt(index)
                }
              }
            }

            Text {
              visible: root.disabledCount < 1 && root.detectNote !== ""
              width: parent.width
              text: root.detectNote
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              id: canvas
              width: parent.width
              implicitHeight: Style.space(168)
              clip: true

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
                model: root.monitors.length

                Rectangle {
                  required property int index
                  readonly property var mon: root.monitors[index]
                  visible: !!mon
                  x: mon ? canvas.cx(mon.x) : 0
                  y: mon ? canvas.cy(mon.y) : 0
                  width: mon ? canvas.cw(mon.logicalW) : 0
                  height: mon ? canvas.ch(mon.logicalH) : 0
                  radius: Math.max(2, Style.cornerRadius)
                  opacity: mon && mon.enabled ? 1 : 0.7
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
                    : Util.alpha(root.bar.foreground, mon && mon.enabled ? 0.28 : 0.45)

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
                      text: mon ? mon.label : ""
                      color: Qt.darker(root.bar.foreground, 1.25)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    Text {
                      visible: !!(mon && !mon.enabled)
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "Off"
                      color: Qt.darker(root.bar.foreground, 1.35)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
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
              visible: root.brightnessAvailable
              width: parent.width
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: Math.max(brightnessHeader.implicitHeight, brightnessPercentLabel.implicitHeight)

                PanelSectionHeader {
                  id: brightnessHeader
                  text: "BRIGHTNESS"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: brightnessPercentLabel
                  text: Math.round(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightnessPercent) + "%"
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              PanelSlider {
                id: brightnessSlider
                width: parent.width
                bar: root.bar
                minimum: 1
                maximum: 100
                step: 1
                value: root.brightnessPercent
                integer: true
                onMoved: function(v) { root.previewBrightness(v) }
                onReleased: function(v) {
                  brightnessDebounce.stop()
                  root.setBrightness(v)
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: Math.max(textSizeHeader.implicitHeight, textSizePx.implicitHeight)

                PanelSectionHeader {
                  id: textSizeHeader
                  text: "TEXT SIZE"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: textSizePx
                  text: (textSizeSlider.dragging
                    ? root.textSizeStops[Math.round(textSizeSlider.liveValue)]
                    : root.displayedTextPx()) + "px"
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              PanelSlider {
                id: textSizeSlider
                width: parent.width
                bar: root.bar
                minimum: 0
                maximum: root.textSizeStops.length - 1
                step: 1
                integer: true
                tickCount: root.textSizeStops.length
                value: root.currentTextIndex()
                onReleased: function(v) { root.setTextSize(root.textSizeStops[Math.round(v)]) }
              }
            }

            Column {
              id: scaleSection
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

            Column {
              id: hdrRow
              width: parent.width
              spacing: Style.space(6)
              visible: root.selectedHdrOk

              Row {
                width: parent.width
                spacing: Style.space(8)

                Dropdown {
                  width: parent.width - (Model.hdrModeOf(root.selected) > 0 ? tuneBtn.width + parent.spacing : 0)
                  label: "HDR"
                  showLabel: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  value: String(Model.hdrModeOf(root.selected))
                  options: root.hdrModeOptions
                  onChanged: function(v) { root.setHdrMode(v) }
                }

                Button {
                  id: tuneBtn
                  visible: Model.hdrModeOf(root.selected) > 0
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.hdrTuning ? "Done" : "Tune"
                  fontSize: Style.font.caption
                  fontFamily: root.bar.fontFamily
                  foreground: root.bar.foreground
                  bordered: true
                  active: root.hdrTuning
                  horizontalPadding: Style.space(10)
                  verticalPadding: Style.space(4)
                  tooltipText: "Bit depth, color space, and SDR brightness"
                  onClicked: {
                    root.hdrTuning = !root.hdrTuning
                    if (root.hdrTuning)
                      Qt.callLater(function() { root.revealItem(hdrTuneSection) })
                  }
                }
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                  var mode = Model.hdrModeOf(root.selected)
                  if (mode === 1)
                    return "Desktop stays SDR. HDR only for fullscreen games and video."
                  if (mode === 2)
                    return "HDR stays on. Can wash out HDR-ready LCDs."
                  return "Leave off unless a game or video needs HDR."
                }
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              Column {
                id: hdrTuneSection
                width: parent.width
                spacing: Style.space(8)
                visible: root.hdrTuning && Model.hdrModeOf(root.selected) > 0

                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  PanelSectionHeader {
                    text: "BIT DEPTH"
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                  }

                  Grid {
                    id: bitdepthRow
                    width: parent.width
                    columns: root.bitdepthOptions.length
                    spacing: Style.spacing.xs
                    readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                    Repeater {
                      model: root.bitdepthOptions

                      Button {
                        required property var modelData
                        width: bitdepthRow.cellWidth
                        text: modelData.label
                        fontSize: Style.font.caption
                        fontFamily: root.bar.fontFamily
                        foreground: root.bar.foreground
                        bordered: true
                        active: root.selected && Number(root.selected.bitdepth) === Number(modelData.value)
                        onClicked: root.setBitdepth(modelData.value)
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Number(root.selected && root.selected.bitdepthCapable) === 8
                      ? "EDID reports 8-bit. 10-bit may still work on DisplayPort."
                      : "10-bit HDR. Use 8-bit if screen capture fails."
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  PanelSectionHeader {
                    text: "COLOR SPACE"
                    foreground: root.bar.foreground
                    fontFamily: root.bar.fontFamily
                  }

                  Grid {
                    id: hdrCmRow
                    width: parent.width
                    columns: root.hdrCmOptions.length
                    spacing: Style.spacing.xs
                    readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                    Repeater {
                      model: root.hdrCmOptions

                      Button {
                        required property var modelData
                        width: hdrCmRow.cellWidth
                        text: modelData.label
                        fontSize: Style.font.caption
                        fontFamily: root.bar.fontFamily
                        foreground: root.bar.foreground
                        bordered: true
                        active: root.selected && String(root.selected.cm) === String(modelData.value)
                        onClicked: root.setHdrCm(modelData.value)
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: root.selected && root.selected.wideGamut
                      ? "Wide is BT.2020. Display uses this panel's measured colors."
                      : "Display matches this LCD. Wide (BT.2020) often looks dull here."
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(sdrBrightHeader.implicitHeight, sdrBrightValue.implicitHeight)

                    PanelSectionHeader {
                      id: sdrBrightHeader
                      text: "SDR BRIGHTNESS"
                      foreground: root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: sdrBrightValue
                      text: {
                        var n = root.selected ? Number(root.selected.sdrBrightness) : 1.0
                        if (!isFinite(n) || n <= 0) n = 1.0
                        return n.toFixed(2) + "×"
                      }
                      color: Qt.darker(root.bar.foreground, 1.4)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  PanelSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 0.8
                    maximum: 2.0
                    step: 0.05
                    value: root.selected && isFinite(Number(root.selected.sdrBrightness)) && Number(root.selected.sdrBrightness) > 0
                      ? Number(root.selected.sdrBrightness) : 1.0
                    onMoved: function(v) { root.setSdrBrightness(v, false) }
                    onReleased: function(v) { root.setSdrBrightness(v, true) }
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Raises the desktop and other SDR apps while HDR is on. Start around 1.2 on LCDs."
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(blackHeader.implicitHeight, blackValue.implicitHeight)

                    PanelSectionHeader {
                      id: blackHeader
                      text: "BLACK FLOOR"
                      foreground: root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: blackValue
                      text: {
                        var n = root.selected ? Number(root.selected.sdrMinLuminance) : 0.005
                        if (!isFinite(n)) n = 0.005
                        return n.toFixed(3) + " nits"
                      }
                      color: Qt.darker(root.bar.foreground, 1.4)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  PanelSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 0
                    maximum: 0.2
                    step: 0.005
                    value: root.selected && isFinite(Number(root.selected.sdrMinLuminance))
                      ? Number(root.selected.sdrMinLuminance) : 0.005
                    onMoved: function(v) { root.setSdrMin(v, false) }
                    onReleased: function(v) { root.setSdrMin(v, true) }
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Lower maps SDR black closer to the panel. Enabling HDR sets 0.005 nits."
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(peakHeader.implicitHeight, peakValue.implicitHeight)

                    PanelSectionHeader {
                      id: peakHeader
                      text: "SDR PEAK"
                      foreground: root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: peakValue
                      text: {
                        var n = root.selected ? Number(root.selected.sdrMaxLuminance) : 200
                        if (!isFinite(n)) n = 200
                        return Math.round(n) + " nits"
                      }
                      color: Qt.darker(root.bar.foreground, 1.4)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  PanelSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 80
                    maximum: 400
                    step: 10
                    integer: true
                    value: root.selected && isFinite(Number(root.selected.sdrMaxLuminance))
                      ? Number(root.selected.sdrMaxLuminance) : 200
                    onMoved: function(v) { root.setSdrMax(v, false) }
                    onReleased: function(v) { root.setSdrMax(v, true) }
                  }

                  Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "SDR white level while HDR is on. Typical range 200–250 nits."
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
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
              description: root.lastDisplayQuip !== ""
                ? root.lastDisplayQuip
                : root.enabledCount <= 1 && root.selected && root.selected.enabled
                  ? "Keep at least one screen on"
                  : root.selectedSecondaryGpu
                    ? "May stay blank until a Hyprland restart or system reboot"
                    : "Include this screen in the layout"
              checked: !!(root.selected && root.selected.enabled) && !root.lastDisplayBounce
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.setEnabled(!(root.selected && root.selected.enabled))
            }

            Text {
              visible: root.selectedSecondaryGpu
              width: parent.width
              wrapMode: Text.WordWrap
              text: "This output is on a non-primary GPU. Disable can leave it blank until a Hyprland restart or a system reboot. Detect can still find it."
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
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

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      visible: root.isStandbyScreen(modelData ? modelData.name : "")
      color: "black"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.namespace: "im0001gt.screens-standby"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
  }
}
