import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
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
  property var conflict: null
  property bool conflictDismissed: false
  property var scaleKeys: ({ status: "" })
  property bool hdrTuning: false
  property bool barCareOpen: false
  property var barCare: Model.normalizeBarCare(null)
  onBarCareChanged: root.applyCareVisuals()
  property bool oledGuard: false
  property bool careDimDragging: false
  property bool allMonitorsBrightness: false
  property int brightnessPercent: 0
  property int pendingBrightnessPercent: 0
  property bool brightnessSetQueued: false
  property bool brightnessAvailable: false
  property var brightnessTargets: []
  property int brightnessQueueIndex: 0
  property int nightlightTemp: 4000
  property int pendingNightlightTemp: 4000
  property bool nightlightEnabled: false
  property bool nightlightSetQueued: false
  property int textSizePreviewIndex: -1
  property bool reflowingText: false
  property bool lastDisplayBounce: false
  property int lastDisplayQuipIndex: 0
  property string lastDisplayQuip: ""
  property bool manageWorkspaces: false
  property var workspacePlan: []
  property var workspaceLayouts: ({})
  property int layoutMenuWorkspace: 0
  property var layoutMenuAnchor: null
  property bool layoutMenuOpen: false
  property bool layoutDirty: false
  property bool pendingConfirm: false
  onPendingConfirmChanged: if (root.careService) root.careService.pendingConfirm = root.pendingConfirm
  property int revertLeft: 20
  onRevertLeftChanged: if (root.careService) root.careService.revertLeft = root.revertLeft
  property var liveMonitors: []
  property int liveTextPx: 12
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
  readonly property var scalePresets: ["1", "1.25", "1.33", "1.5", "2"]
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
  readonly property var wideColorOptions: [
    { value: "0", label: "Auto" },
    { value: "1", label: "Force" },
    { value: "-1", label: "Off" }
  ]
  readonly property var hdrCmOptions: [
    { value: "auto", label: "Auto" },
    { value: "srgb", label: "sRGB" },
    { value: "edid", label: "EDID" },
    { value: "dcip3", label: "DCI-P3" },
    { value: "dp3", label: "Display P3" },
    { value: "adobe", label: "Adobe RGB" },
    { value: "wide", label: "BT.2020" },
    { value: "hdredid", label: "HDR Display" },
    { value: "hdr", label: "HDR Wide" }
  ]
  readonly property var sdrCmOptions: [
    { value: "auto", label: "Auto" },
    { value: "srgb", label: "sRGB" },
    { value: "edid", label: "EDID" },
    { value: "dcip3", label: "DCI-P3" },
    { value: "dp3", label: "Display P3" },
    { value: "adobe", label: "Adobe RGB" },
    { value: "wide", label: "BT.2020" }
  ]
  readonly property var sdrEotfOptions: [
    { value: "default", label: "Default" },
    { value: "srgb", label: "sRGB" },
    { value: "gamma22", label: "Gamma 2.2" }
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
  readonly property var careService: {
    try {
      return root.bar && root.bar.shell && typeof root.bar.shell.serviceFor === "function"
        ? root.bar.shell.serviceFor("im0001gt.screens") : null
    } catch (e) {
      return null
    }
  }
  readonly property string carePath:
    Quickshell.env("HOME") + "/.local/state/im0001gt.screens/bar-care.json"
  readonly property string panelStatePath:
    Quickshell.env("HOME") + "/.local/state/im0001gt.screens/panel.json"
  property bool stickyPanel: false
  property string panelOwnerScreen: ""
  property int resumeTries: 0
  property bool panelScrolling: false
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
    if (root.layoutDirty || root.pendingConfirm) {
      if (root.opened) {
        root.refreshBrightness()
        root.refreshNightlight()
      }
      return
    }
    if (!stateProc.running) stateProc.running = true
    if (root.opened) {
      root.refreshBrightness()
      root.refreshNightlight()
    }
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

  function brightnessNames() {
    var names = []
    var i, m, name
    if (root.allMonitorsBrightness) {
      for (i = 0; i < root.monitors.length; i++) {
        m = root.monitors[i]
        name = m && m.name ? String(m.name) : ""
        if (name && m.enabled !== false) names.push(name)
      }
    } else {
      name = root.brightnessMonitor()
      if (name) names.push(name)
    }
    return names
  }

  function pumpBrightness() {
    if (root.brightnessQueueIndex >= root.brightnessTargets.length) return
    var name = root.brightnessTargets[root.brightnessQueueIndex]
    root.brightnessQueueIndex += 1
    setBrightnessProc.command = [
      "omarchy-brightness-display", "--no-osd", "--monitor", name,
      root.pendingBrightnessPercent + "%"
    ]
    setBrightnessProc.running = true
  }

  function setBrightness(value) {
    var percent = Model.clampBrightness(value)
    var names = root.brightnessNames()
    root.brightnessPercent = percent
    root.pendingBrightnessPercent = percent
    if (!names.length) return
    if (setBrightnessProc.running) {
      root.brightnessSetQueued = true
      return
    }
    root.brightnessSetQueued = false
    root.brightnessTargets = names
    root.brightnessQueueIndex = 0
    root.pumpBrightness()
  }

  function previewBrightness(value) {
    root.brightnessPercent = Model.clampBrightness(value)
    brightnessDebounce.restart()
  }

  function refreshNightlight() {
    if (setNightlightProc.running) return
    if (nightlightSlider && nightlightSlider.dragging) return
    if (!nightlightProbeProc.running) nightlightProbeProc.running = true
  }

  function setNightlight(value) {
    var temp = Model.clampNightlight(value)
    root.nightlightTemp = temp
    root.pendingNightlightTemp = temp
    root.nightlightEnabled = Model.nightlightIsOn(temp)
    if (setNightlightProc.running) {
      root.nightlightSetQueued = true
      return
    }
    root.nightlightSetQueued = false
    setNightlightProc.command = ["bash", "-lc",
      "pgrep -x hyprsunset >/dev/null || { setsid uwsm-app -- hyprsunset >/dev/null 2>&1 & sleep 1; }; " +
      "hyprctl hyprsunset temperature " + temp + " >/dev/null 2>&1; " +
      "omarchy-shell -q nightlight refresh >/dev/null 2>&1 || true"
    ]
    setNightlightProc.running = true
  }

  function previewNightlight(value) {
    root.nightlightTemp = Model.clampNightlight(value)
    root.nightlightEnabled = Model.nightlightIsOn(root.nightlightTemp)
    nightlightDebounce.restart()
  }

  function setNightlightEnabled(enable) {
    if (enable) {
      var target = Model.nightlightIsOn(root.nightlightTemp) ? root.nightlightTemp : 4000
      root.setNightlight(target)
      return
    }
    root.setNightlight(6500)
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
    var px = root.selected && Number(root.selected.textPx) >= 9
      ? Number(root.selected.textPx)
      : Style.font.baseSize
    return root.nearestTextStop(px)
  }

  function displayedTextPx() {
    if (root.selected && Number(root.selected.textPx) >= 9)
      return Number(root.selected.textPx)
    return Style.font.baseSize
  }

  function setTextSize(px) {
    var stop = root.textSizeStops[root.nearestTextStop(px)]
    mutateSelected(function(m) { m.textPx = stop })
  }

  function captureLive(list) {
    root.liveMonitors = Model.clone(list || root.monitors)
    root.liveTextPx = Style.font.baseSize
  }

  function applyPendingTextSize() {
    var px = root.selected && Number(root.selected.textPx) >= 9
      ? Number(root.selected.textPx)
      : 0
    if (!px || px === root.liveTextPx) return
    textScaleProc.command = ["omarchy-display-text-size", String(px)]
    if (!textScaleProc.running) textScaleProc.running = true
  }

  function restoreLiveTextSize() {
    var px = root.liveTextPx
    if (!(px >= 9)) px = 12
    textScaleProc.command = ["omarchy-display-text-size", String(px)]
    if (!textScaleProc.running) textScaleProc.running = true
  }

  function undoDraft() {
    if (root.pendingConfirm) {
      root.revertLayout()
      return
    }
    if (root.liveMonitors && root.liveMonitors.length)
      root.monitors = Model.clone(root.liveMonitors)
    root.layoutDirty = false
    root.textSizePreviewIndex = -1
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
    root.manageWorkspaces = !!(data && data.manageWorkspaces)
    root.workspacePlan = (data && data.workspacePlan) ? data.workspacePlan : []
    root.workspaceLayouts = (data && data.workspaceLayouts) ? data.workspaceLayouts : ({})
    root.oledGuard = !!(data && data.oledGuard)
    if (data && data.hybridNotice === false) root.showHybridNotice = false
    else if (root.opened && data && data.hybridNotice) root.showHybridNotice = true
    if (data && data.conflict && data.conflict.present !== false)
      root.conflict = data.conflict
    else
      root.conflict = null
    root.scaleKeys = (data && data.scaleKeys) ? data.scaleKeys : ({ status: "" })
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
    if (!root.layoutDirty && !root.pendingConfirm)
      root.captureLive(list)
    var key = (data && data.connectedKey) ? String(data.connectedKey) : ""
    var prev = root.lastKey
    if (key) root.lastKey = key
    if (prev !== "" && key !== "" && prev !== key
        && !root.opened && !root.dragging && !root.applying) {
      if (root.autoSwitch && root.matchProfile) root.applyProfile(root.matchProfile)
      else if (root.manageWorkspaces) root.syncWorkspaces()
    }
  }

  function mutateSelected(fn) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    fn(next[root.selectedIndex], next, root.selectedIndex)
    root.monitors = next
    root.layoutDirty = true
  }

  function applyNow(preview) {
    if (applyProc.running) {
      root.applying = true
      return
    }
    var payload = JSON.stringify(Model.applyPayload(Model.normalizeOrigin(Model.clone(root.monitors))))
    applyProc.command = preview
      ? [root.ctl, "apply", "--preview", payload]
      : [root.ctl, "apply", payload]
    root.applying = true
    if (preview) {
      root.pendingConfirm = true
      root.revertLeft = 20
      revertTick.restart()
      root.stickyPanel = true
      root.claimPanelOwner()
      root.writePanelState(true, true, Date.now() / 1000 + 20)
      root.armDismissGuard()
      root.startResumeRetry()
      if (!root.opened) root.open()
    }
    applyProc.running = true
  }

  function claimPanelOwner() {
    var name = root.barScreenName
    if (!name) return
    root.panelOwnerScreen = name
    if (root.careService) root.careService.panelScreen = name
  }

  function armDismissGuard() {
    dismissGuard.restart()
  }

  function startResumeRetry() {
    root.resumeTries = 0
    if (!resumeRetry.running) resumeRetry.restart()
    Qt.callLater(root.forceShowPanel)
  }

  function shouldHoldPanel() {
    return root.applying || dismissGuard.running
  }

  function isPanelOwner() {
    var owner = ""
    if (root.careService && root.careService.panelScreen)
      owner = String(root.careService.panelScreen)
    if (!owner) owner = root.panelOwnerScreen
    if (!owner || owner === root.barScreenName) return true
    var screens = Quickshell.screens
    var i
    for (i = 0; i < (screens ? screens.length : 0); i++) {
      if (String(screens[i].name) === owner) return false
    }
    return true
  }

  function open() {
    root.stickyPanel = true
    root.claimPanelOwner()
    if (root.careService) {
      root.careService.panelWanted = true
      if (root.isPanelOwner()) root.careService.panelMapped = true
    }
    root.controller.show()
  }

  function close() {
    // Scale/layout apply remaps layer surfaces. KeyboardPanel's other-output
    // dismiss overlay then sees a synthetic press and would wipe Keep/Revert.
    if (root.shouldHoldPanel()) {
      root.stickyPanel = true
      root.armDismissGuard()
      Qt.callLater(root.forceShowPanel)
      return
    }
    root.stickyPanel = false
    if (root.careService) {
      root.careService.panelWanted = false
      root.careService.panelMapped = false
      root.careService.panelScreen = ""
    }
    root.writePanelState(false, false, 0)
    root.controller.hide()
  }

  function writePanelState(wanted, pending, deadline) {
    if (!panelStateFile) return
    panelStateFile.setText(JSON.stringify({
      wanted: !!wanted,
      pendingConfirm: !!pending,
      deadline: Number(deadline) || 0,
      screen: wanted ? (root.panelOwnerScreen || root.barScreenName) : ""
    }) + "\n")
  }

  function applyPanelState(data) {
    if (!data) return
    var wanted = !!data.wanted
    var pending = !!data.pendingConfirm
    if (!wanted && root.shouldHoldPanel()) return
    var screen = String(data.screen || "")
    root.stickyPanel = wanted
    if (wanted && screen) root.panelOwnerScreen = screen
    if (root.careService) {
      root.careService.panelWanted = wanted
      root.careService.pendingConfirm = pending
      if (wanted && screen) root.careService.panelScreen = screen
      if (!wanted) {
        root.careService.panelMapped = false
        root.careService.panelScreen = ""
      }
    }
    if (pending) {
      root.pendingConfirm = true
      var left = Math.ceil(Number(data.deadline || 0) - Date.now() / 1000)
      if (left < 1) left = 1
      if (left > 30) left = 30
      root.revertLeft = left
      if (!revertTick.running) revertTick.restart()
    }
    if (wanted) root.startResumeRetry()
  }

  function forceShowPanel() {
    if (!root.stickyPanel) return
    var win = root.barWindow()
    if (!win || !win.screen) return
    if (root.isPanelOwner()) {
      if (!root.opened) root.controller.show()
      return
    }
    var ownerMapped = root.careService && root.careService.panelMapped
    if (root.resumeTries >= 2 && !ownerMapped) {
      if (!root.opened) root.controller.show()
      return
    }
    if (root.opened) root.controller.hide()
  }

  function resumePanel() {
    root.forceShowPanel()
  }

  function remountPanel() {
    if (!root.stickyPanel && !root.pendingConfirm) return
    root.stickyPanel = true
    if (root.careService) root.careService.panelWanted = true
    root.armDismissGuard()
    if (!root.isPanelOwner()) return
    if (root.opened) root.controller.hide()
    Qt.callLater(root.forceShowPanel)
  }

  function applyDraft() {
    applyNow(true)
    root.applyPendingTextSize()
  }

  function keepLayout() {
    revertTick.stop()
    root.pendingConfirm = false
    root.layoutDirty = false
    root.captureLive(root.monitors)
    root.writePanelState(true, false, 0)
    keepProc.command = [root.ctl, "confirm"]
    if (!keepProc.running) keepProc.running = true
  }

  function revertLayout() {
    revertTick.stop()
    root.pendingConfirm = false
    root.layoutDirty = false
    root.restoreLiveTextSize()
    if (revertProc.running) return
    revertProc.command = [root.ctl, "revert"]
    root.applying = true
    root.armDismissGuard()
    revertProc.running = true
  }

  function resizeSelected(mutator) {
    mutateSelected(function(m, list, idx) {
      var oldW = Model.logicalW(m)
      var oldH = Model.logicalH(m)
      mutator(m)
      var dim = Model.sizeFromMode(m.mode)
      if (dim.width) m.width = dim.width
      if (dim.height) m.height = dim.height
      Model.applyLogicalSize(m)
      Model.reflowAfterResize(list, idx, oldW, oldH)
    })
  }

  function setMode(mode) {
    root.resizeSelected(function(m) { m.mode = mode })
  }

  function setResolution(res) {
    root.resizeSelected(function(m) {
      var hz = parseFloat(String(m.mode || "").split("@")[1])
      m.mode = Model.pickMode(m, res, hz)
    })
  }

  function setScale(scale, reveal) {
    root.resizeSelected(function(m) { m.scale = Math.round(Number(scale) * 100) / 100 })
    if (reveal) Qt.callLater(function() { root.revealItem(scaleSection) })
  }

  function setTransform(value) {
    root.resizeSelected(function(m) { m.transform = parseInt(value, 10) || 0 })
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
      if (n === 0) {
        if (m.cm === "hdr" || m.cm === "hdredid") m.cm = "srgb"
        return
      }
      var capable = Number(m.bitdepthCapable) >= 10 ? 10 : 8
      if (Number(m.bitdepth) !== 8 && Number(m.bitdepth) !== 10)
        m.bitdepth = capable
      if (n === 2 && m.cm !== "hdr" && m.cm !== "hdredid")
        m.cm = m.wideGamut ? "hdr" : "hdredid"
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

  function setWideColor(value) {
    var n = parseInt(value, 10)
    if (n !== 1 && n !== -1) n = 0
    mutateSelected(function(m) { m.supportsWideColor = n })
  }

  function setHdrCm(value) {
    var cm = String(value || "srgb")
    if ((cm === "hdr" || cm === "hdredid") && Model.hdrModeOf(root.selected) === 0)
      root.setHdrMode(2)
    mutateSelected(function(m) { m.cm = cm })
  }

  function setSdrSaturation(value) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrSaturation = Math.max(0.5, Math.min(2.0, Math.round(Number(value) * 20) / 20))
    root.monitors = next
    root.layoutDirty = true
  }

  function setSdrEotf(value) {
    mutateSelected(function(m) { m.sdrEotf = String(value || "default") })
  }

  function setSdrMin(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrMinLuminance = Math.max(0, Math.min(0.2, Number(value)))
    root.monitors = next
    root.layoutDirty = true
  }

  function setSdrMax(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrMaxLuminance = Math.max(40, Math.min(400, Math.round(Number(value))))
    root.monitors = next
    root.layoutDirty = true
  }

  function setSdrBrightness(value, apply) {
    if (!root.selected) return
    var next = Model.clone(root.monitors)
    next[root.selectedIndex].sdrBrightness = Math.max(0.8, Math.min(2.0, Math.round(Number(value) * 20) / 20))
    root.monitors = next
    root.layoutDirty = true
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
    root.layoutDirty = true
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

  function dismissConflict() {
    root.conflictDismissed = true
  }

  readonly property bool hyprmoncfgConflict: {
    var id = root.conflict && root.conflict.id ? String(root.conflict.id) : ""
    return id === "crmne.hyprmoncfg" || id === "display-managers" || id === "hyprmoncfg"
  }

  function runConflictAction(action) {
    conflictActionProc.command = [root.ctl, "conflicts", action]
    if (!conflictActionProc.running) conflictActionProc.running = true
  }

  function setScaleKeys(action) {
    root.runStore(["scale-keys", action])
  }

  function setPrimary() {
    if (!root.selected) return
    root.userPicked = true
    root.runStore(["profile", "primary", root.selected.identity || ""])
  }

  function setManageWorkspaces(on) {
    root.manageWorkspaces = !!on
    root.runStore(["workspaces", on ? "on" : "off"])
  }

  function syncWorkspaces() {
    root.runStore(["workspaces", "sync"])
  }

  function clonePlan(plan) {
    var out = []
    for (var i = 0; i < plan.length; i++) {
      var p = plan[i]
      out.push({
        name: p.name,
        identity: p.identity || "",
        label: p.label || "",
        ids: (p.ids || []).slice(),
        first: p.first,
        last: p.last
      })
    }
    return out
  }

  function assignedWorkspaceIds(mon) {
    if (!mon) return []
    var p = Model.planForMonitor(root.workspacePlan, mon)
    return (p && p.ids) ? p.ids : []
  }

  function workspaceAssignedTo(mon, id) {
    return root.assignedWorkspaceIds(mon).indexOf(id) !== -1
  }

  function workspaceHolderId(id) {
    var list = root.monitors
    for (var i = 0; i < list.length; i++) {
      if (!list[i].enabled) continue
      if (root.workspaceAssignedTo(list[i], id)) return list[i].name
    }
    return ""
  }

  function unassignedWorkspaceIds() {
    var out = []
    for (var id = 1; id <= 10; id++) {
      if (!root.workspaceHolderId(id)) out.push(id)
    }
    return out
  }

  function toggleWorkspaceAssignment(mon, id) {
    if (!mon || !id) return
    var next = root.clonePlan(root.workspacePlan)
    var target = Model.planForMonitor(next, mon)
    if (!target) {
      target = { name: mon.name, identity: mon.identity || "", label: mon.label || mon.name, ids: [] }
      next.push(target)
    }
    var idx = target.ids.indexOf(id)
    if (idx >= 0) {
      target.ids.splice(idx, 1)
    } else {
      target.ids.push(id)
      for (var i = 0; i < next.length; i++) {
        if (next[i] === target) continue
        var k = (next[i].ids || []).indexOf(id)
        if (k >= 0) next[i].ids.splice(k, 1)
      }
      target.ids.sort(function(a, b) { return a - b })
    }
    root.pushWorkspacePlan(next)
  }

  function autoSplitWorkspaces() {
    root.runStore(["workspaces", "auto"])
  }

  function pushWorkspacePlan(plan) {
    var payload = []
    for (var i = 0; i < root.monitors.length; i++) {
      var m = root.monitors[i]
      if (!m.enabled) continue
      var p = Model.planForMonitor(plan, m)
      payload.push({ name: m.name, ids: (p && p.ids) ? p.ids : [] })
    }
    root.runStore(["workspaces", "assign", JSON.stringify(payload)])
  }

  function setWorkspaceLayout(id, mode) {
    root.layoutMenuOpen = false
    var n = Model.workspaceId(id)
    if (!n) return
    root.runStore(["workspace-layout", String(n), mode])
  }

  function focusWorkspace(id) {
    var n = Model.workspaceId(id)
    if (!n) return
    focusWsProc.command = [
      "hyprctl", "eval",
      "hl.dispatch(hl.dsp.focus({ workspace = \"" + n + "\" }))"
    ]
    if (!focusWsProc.running) focusWsProc.running = true
  }

  function openLayoutMenu(id, anchor) {
    root.layoutMenuWorkspace = id
    root.layoutMenuAnchor = anchor
    root.layoutMenuOpen = true
  }

  property var careHover: null
  readonly property var careWindow: (typeof button !== "undefined" && button && button.QsWindow)
    ? button.QsWindow.window
    : (root.QsWindow ? root.QsWindow.window : null)
  onCareWindowChanged: root.applyCareVisuals()

  function hostBar() {
    var host = Model.findHostBar(root)
    if (host) return host
    if (root.bar && root.bar.moduleSlots) return root.bar
    return null
  }

  function barWindow() {
    if (typeof button !== "undefined" && button && button.QsWindow && button.QsWindow.window)
      return button.QsWindow.window
    if (root.QsWindow && root.QsWindow.window)
      return root.QsWindow.window
    return null
  }

  function ensureCareHover() {
    var win = root.barWindow()
    if (!win || !win.contentItem) return null
    if (root.careHover) return root.careHover
    try {
      root.careHover = Qt.createQmlObject("import QtQuick; HoverHandler { }", win.contentItem)
      root.careHover.hoveredChanged.connect(function() { root.applyCareVisuals() })
    } catch (e) {
      root.careHover = null
    }
    return root.careHover
  }

  function applyCareVisuals() {
    var win = root.barWindow()
    var hover = root.ensureCareHover()
    var hovered = !!(hover && hover.hovered)
    if (Model.applyBarCareToWindow(win, root.barCare, { hovered: hovered }))
      return
    Model.applyBarCare(root.hostBar(), root.barCare, { hovered: hovered })
  }

  function pushCareToService(next) {
    root.applyCareVisuals()
    if (!root.careService) return
    root.careService.careConfig = next
    if (typeof root.careService.applyCareVisuals === "function")
      root.careService.applyCareVisuals()
  }

  function saveBarCare() {
    if (!careFile) return
    careFile.setText(JSON.stringify(root.barCare, null, 2) + "\n")
  }

  function setBarCare(key, value, persist) {
    var next = Model.normalizeBarCare(root.barCare)
    next[key] = value
    next = Model.normalizeBarCare(next)
    root.barCare = next
    root.pushCareToService(next)
    if (persist !== false) root.saveBarCare()
  }

  function workspaceDescription() {
    var hint = "Right-click a number to name it, pick an icon, or set Tile, Scroll, or Float."
    if (root.enabledCount <= 1)
      return "Keep workspaces 1–10 on this screen. " + hint
    if (root.enabledCount === 2)
      return "Primary gets 1–5, the next screen gets 6–10. " + hint
    return "Split ten workspaces across these screens. " + hint
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

  Component.onCompleted: {
    refresh()
    root.applyCareVisuals()
    if (root.careService && root.careService.pendingConfirm) {
      root.pendingConfirm = true
      root.revertLeft = root.careService.revertLeft || 20
      revertTick.restart()
    }
    if (root.careService && root.careService.panelWanted) {
      root.stickyPanel = true
      root.panelOwnerScreen = root.careService.panelScreen || root.panelOwnerScreen
      root.startResumeRetry()
    }
  }
  Component.onDestruction: {
    if (root.careHover) {
      try { root.careHover.destroy() } catch (e) {}
      root.careHover = null
    }
    var win = root.barWindow()
    if (win && win.contentItem) win.contentItem.opacity = 1
  }
  onOpenedChanged: {
    if (opened) {
      root.stickyPanel = true
      if (root.careService) {
        root.careService.panelWanted = true
        if (root.isPanelOwner()) root.careService.panelMapped = true
      }
      root.userPicked = false
      root.lastDisplayBounce = false
      root.lastDisplayQuip = ""
      refresh()
      return
    }
    if (root.careService && root.careService.panelScreen === root.barScreenName)
      root.careService.panelMapped = false
    if ((root.shouldHoldPanel() || root.stickyPanel) && root.isPanelOwner()) {
      Qt.callLater(root.forceShowPanel)
      return
    }
    if (root.stickyPanel) return
    root.detectNote = ""
    root.detectPending = false
    root.hdrTuning = false
    root.barCareOpen = false
    if (root.pendingConfirm) root.revertLayout()
    else if (root.layoutDirty) root.undoDraft()
  }

  onSelectedIndexChanged: if (root.opened) root.refreshBrightness()

  readonly property int screenCount: Quickshell.screens ? Quickshell.screens.length : 0
  onScreenCountChanged: {
    if (root.stickyPanel || root.pendingConfirm) {
      root.armDismissGuard()
      root.startResumeRetry()
      Qt.callLater(root.remountPanel)
    }
  }

  readonly property string monitorFingerprint: {
    var vals = Hyprland.monitors && Hyprland.monitors.values
    var parts = []
    var i, mon
    for (i = 0; i < (vals ? vals.length : 0); i++) {
      mon = vals[i]
      parts.push(String(mon.name || "") + ":" + String(mon.scale || "") + ":" + String(mon.transform || ""))
    }
    return parts.join("|")
  }
  onMonitorFingerprintChanged: {
    if (root.stickyPanel || root.pendingConfirm) {
      var remapOwner = root.opened && root.isPanelOwner()
      root.armDismissGuard()
      root.startResumeRetry()
      if (remapOwner) Qt.callLater(root.remountPanel)
    }
  }

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
    running: !root.dragging && !root.applying && !root.layoutDirty && !root.pendingConfirm
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

  Timer {
    id: dismissGuard
    interval: 2500
  }

  Timer {
    id: resumeRetry
    interval: 200
    repeat: true
    onTriggered: {
      root.resumeTries += 1
      if (!root.stickyPanel || root.resumeTries >= 15
          || (root.opened && root.isPanelOwner())) {
        running = false
        return
      }
      root.forceShowPanel()
    }
  }

  Timer {
    id: revertTick
    interval: 1000
    repeat: true
    onTriggered: {
      root.revertLeft = root.revertLeft - 1
      if (root.revertLeft <= 0) root.revertLayout()
    }
  }

  Process {
    id: keepProc
    stdout: StdioCollector { waitForEnd: true }
  }

  Process {
    id: revertProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.applying = false
        try { root.adopt(JSON.parse(text)) }
        catch (e) { root.refresh() }
      }
    }
    onExited: function(code) {
      root.applying = false
      if (code !== 0) root.refresh()
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (root.stickyPanel || root.pendingConfirm)
          root.armDismissGuard()
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
        if (root.stickyPanel || root.pendingConfirm)
          root.startResumeRetry()
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
    id: focusWsProc
    stdout: StdioCollector { waitForEnd: true }
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
    id: panelScrollIdle
    interval: 420
    onTriggered: root.panelScrolling = false
  }

  Timer {
    id: brightnessDebounce
    interval: 180
    repeat: false
    onTriggered: root.setBrightness(root.brightnessPercent)
  }

  FileView {
    id: careFile
    path: root.carePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.careDimDragging) return
      try { root.barCare = Model.normalizeBarCare(JSON.parse(text())) }
      catch (e) {}
    }
    onFileChanged: reload()
    Component.onCompleted: reload()
  }

  FileView {
    id: panelStateFile
    path: root.panelStatePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try { root.applyPanelState(JSON.parse(text() || "{}")) }
      catch (e) {}
    }
    onFileChanged: reload()
    Component.onCompleted: reload()
  }



  Process {
    id: conflictActionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.adopt(JSON.parse(text)) }
        catch (e) { root.refresh() }
        if (!(root.conflict && root.conflict.blocking))
          root.conflictDismissed = true
      }
    }
  }

  Process {
    id: setBrightnessProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      if (root.brightnessSetQueued) {
        root.setBrightness(root.pendingBrightnessPercent)
        return
      }
      if (root.brightnessQueueIndex < root.brightnessTargets.length)
        root.pumpBrightness()
    }
  }

  Process {
    id: nightlightProbeProc
    command: ["omarchy-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (nightlightSlider && nightlightSlider.dragging) return
        try {
          var data = JSON.parse(text || "{}")
          var t = data.temperature
          if (t === null || t === undefined || t === "") return
          root.nightlightTemp = Model.clampNightlight(t)
          root.nightlightEnabled = Model.nightlightIsOn(root.nightlightTemp)
        } catch (e) {}
      }
    }
  }

  Process {
    id: setNightlightProc
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: {
      if (running) return
      if (root.nightlightSetQueued) root.setNightlight(root.pendingNightlightTemp)
    }
  }

  Timer {
    id: nightlightDebounce
    interval: 120
    repeat: false
    onTriggered: root.setNightlight(root.nightlightTemp)
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
        anchors.bottomMargin: applyDock.visible ? applyDock.height : 0
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height && !root.dragging
        onMovementStarted: {
          root.panelScrolling = true
          panelScrollIdle.restart()
        }
        onMovementEnded: panelScrollIdle.restart()
        onFlickStarted: {
          root.panelScrolling = true
          panelScrollIdle.restart()
        }

        Column {
          id: panelColumn
          width: panelFlick.width
          spacing: Style.space(10)

          Column {
            visible: !!(root.conflict && !root.conflictDismissed)
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: (root.conflict && root.conflict.message)
                ? root.conflict.message
                : "Another display tool is still managing your screens."
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              visible: root.hyprmoncfgConflict

              Button {
                visible: !!(root.conflict && (root.conflict.canUnmanage || root.conflict.unmanaged))
                width: (parent.width - parent.spacing) / (root.conflict && root.conflict.canRemove ? 2 : 1)
                text: (root.conflict && root.conflict.blocking) ? "Keep unmanaged" : "Keep it"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                tooltipText: (root.conflict && root.conflict.blocking)
                  ? "Run hyprmoncfg unmanage so Screens can take over. The hyprmoncfg plugin can stay installed."
                  : "Leave hyprmoncfg installed. It is not managing Hyprland."
                onClicked: root.runConflictAction((root.conflict && root.conflict.blocking) ? "unmanage" : "keep")
              }

              Button {
                visible: !!(root.conflict && root.conflict.canRemove)
                width: (parent.width - parent.spacing) / (root.conflict && (root.conflict.canUnmanage || root.conflict.unmanaged) ? 2 : 1)
                text: "Remove hyprmoncfg"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                tooltipText: "Unmanage, then remove the crmne.hyprmoncfg plugin. The AUR package is left unless you drop it yourself."
                onClicked: root.runConflictAction("remove")
              }
            }

            Button {
              text: root.hyprmoncfgConflict ? "Later" : "Got it"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: root.dismissConflict()
            }
          }

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

          Item {
            width: parent.width
            implicitHeight: Math.max(pixelCareLabel.implicitHeight, pixelCareBtn.implicitHeight)

            PanelSectionHeader {
              id: pixelCareLabel
              text: "PIXEL CARE"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Button {
              id: pixelCareBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: root.barCareOpen ? "Done" : (!!(root.barCare && root.barCare.enabled) ? "On" : "Off")
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              active: root.barCareOpen || !!(root.barCare && root.barCare.enabled)
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              tooltipText: "Dim the bar without painting it black. Works on any display."
              onClicked: {
                root.barCareOpen = !root.barCareOpen
                if (root.barCareOpen)
                  Qt.callLater(function() { root.revealItem(barCareSection) })
              }
            }
          }

          Column {
            id: barCareSection
            width: parent.width
            spacing: Style.space(8)
            visible: root.barCareOpen

            Toggle {
              width: parent.width
              label: "Dim the bar"
              description: "Lowers the bar widgets so a transparent or themed bar stays that colour. No black veil."
              checked: !!(root.barCare && root.barCare.enabled)
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.setBarCare("enabled", !(root.barCare && root.barCare.enabled))
            }

            Text {
              visible: root.oledGuard
              width: parent.width
              wrapMode: Text.WordWrap
              text: "OLED Guard is also installed. Its black veil will fight this — disable or remove it if the bar turns black."
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              enabled: !!(root.barCare && root.barCare.enabled)
              opacity: enabled ? 1 : 0.45

              Item {
                width: parent.width
                implicitHeight: Math.max(dimLabel.implicitHeight, dimValue.implicitHeight)

                PanelSectionHeader {
                  id: dimLabel
                  text: "DIM"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: dimValue
                  text: Model.clampBarDim(root.barCare && root.barCare.dim) + "%"
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              ScreensSlider {
                width: parent.width
                bar: root.bar
                minimum: 0
                maximum: 100
                step: 1
                integer: true
                value: Model.clampBarDim(root.barCare && root.barCare.dim)
                onMoved: function(v) {
                  root.careDimDragging = true
                  root.setBarCare("dim", Model.clampBarDim(v), false)
                }
                onReleased: function(v) {
                  root.careDimDragging = false
                  root.setBarCare("dim", Model.clampBarDim(v))
                }
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "How far the bar settles. 100% is fully dim. Hover can lift it back."
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              Toggle {
                width: parent.width
                label: "Lift when I point at the bar"
                description: "Clears the dim the moment the pointer reaches the bar."
                checked: !!(root.barCare && root.barCare.hoverLift)
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.setBarCare("hoverLift", !(root.barCare && root.barCare.hoverLift))
              }
            }
          }

          Column {
            visible: !!(root.scaleKeys && root.scaleKeys.status === "pending")
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: (root.scaleKeys && root.scaleKeys.message)
                ? root.scaleKeys.message
                : "Super+/ is already bound to something that is not Omarchy Display scale. Screens will not steal it unless you say so."
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              width: parent.width
              text: "Use Super+/ for scale"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              tooltipText: "Take Super+/ and Super+Alt+/ for Screens scale, like stock Display."
              onClicked: root.setScaleKeys("take")
            }

            Button {
              width: parent.width
              visible: !!(root.scaleKeys && root.scaleKeys.altUp)
              text: "Use " + ((root.scaleKeys && root.scaleKeys.altUp) ? root.scaleKeys.altUp : "Super+Ctrl+/") + " instead"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              tooltipText: "Leave your current Super+/ bind and put scale on a free pair."
              onClicked: root.setScaleKeys("alt")
            }

            Button {
              width: parent.width
              text: "Keep my keybind"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              tooltipText: "Do not bind scale keys. Change scale from this panel."
              onClicked: root.setScaleKeys("skip")
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
              readonly property real drawnW: box.w * fit
              readonly property real drawnH: box.h * fit
              readonly property real ox: pad + Math.max(0, (width - pad * 2 - drawnW) / 2)
              readonly property real oy: pad + Math.max(0, (height - pad * 2 - drawnH) / 2)
              function cx(x) { return ox + (x - box.x) * fit }
              function cy(y) { return oy + (y - box.y) * fit }
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
                      visible: !root.manageWorkspaces
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: String(index + 1)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.title
                      font.bold: true
                    }

                    Text {
                      visible: root.manageWorkspaces
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: {
                        var p = Model.planForMonitor(root.workspacePlan, mon)
                        return p ? Model.workspaceRangeLabel(p.first, p.last) : ""
                      }
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
                  root.layoutDirty = true
                }
              }

              Repeater {
                model: root.monitors.length

                Item {
                  id: tileChips
                  required property int index
                  readonly property var mon: root.monitors[index]
                  readonly property var plan: Model.planForMonitor(root.workspacePlan, mon)
                  visible: root.manageWorkspaces && !!(mon && mon.enabled && plan && plan.ids && plan.ids.length)
                  x: mon ? canvas.cx(mon.x) : 0
                  y: mon ? canvas.cy(mon.y) : 0
                  width: mon ? canvas.cw(mon.logicalW) : 0
                  height: mon ? canvas.ch(mon.logicalH) : 0
                  z: 4

                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Style.space(4)
                    spacing: Style.space(4)

                    Repeater {
                      model: tileChips.plan && tileChips.plan.ids ? tileChips.plan.ids : []

                      Text {
                        required property int modelData
                        text: Model.workspaceDigit(modelData)
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        opacity: 0.95

                        MouseArea {
                          anchors.fill: parent
                          anchors.margins: -Style.space(4)
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          preventStealing: true
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton)
                              root.openLayoutMenu(modelData, parent)
                            else
                              root.focusWorkspace(modelData)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

          }

          Toggle {
            width: parent.width
            label: "Spread workspaces"
            description: root.workspaceDescription()
            checked: root.manageWorkspaces
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onClicked: root.setManageWorkspaces(!root.manageWorkspaces)
          }

          Column {
            width: parent.width
            spacing: Style.space(8)
            visible: root.manageWorkspaces

            Column {
              width: parent.width
              spacing: Style.space(2)

              PanelSectionHeader {
                text: "ASSIGNED WORKSPACES"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "tap a digit to place it"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Repeater {
              model: root.monitors.length

              Column {
                id: wsRow
                required property int index
                readonly property var mon: root.monitors[index]
                readonly property bool rowVisible: root.manageWorkspaces && !!(mon && mon.enabled && !mon.mirror)
                width: parent.width
                spacing: Style.space(4)
                visible: rowVisible

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: wsRow.mon ? (wsRow.mon.label || wsRow.mon.name) : ""
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(4)

                  Repeater {
                    model: 10

                    Item {
                      id: wsCell
                      required property int index
                      readonly property int wid: index + 1
                      readonly property var mon: wsRow.mon
                      readonly property bool assignedHere: mon ? root.workspaceAssignedTo(mon, wid) : false
                      readonly property bool dimmed: {
                        if (!mon || assignedHere) return false
                        var holder = root.workspaceHolderId(wid)
                        return holder !== "" && holder !== (mon ? mon.name : "")
                      }
                      width: Style.space(22)
                      height: Style.space(22)

                      Rectangle {
                        anchors.fill: parent
                        radius: Style.space(2)
                        color: wsCell.assignedHere
                          ? Util.alpha(Color.accent, 0.9)
                          : (wsCell.dimmed ? "transparent" : Util.alpha(root.bar.foreground, 0.12))
                        border.width: wsCell.assignedHere ? 0 : 1
                        border.color: Util.alpha(root.bar.foreground, wsCell.dimmed ? 0.16 : 0.3)
                      }

                      Text {
                        anchors.centerIn: parent
                        text: Model.workspaceDigit(wsCell.wid)
                        color: wsCell.assignedHere
                          ? Color.background
                          : (wsCell.dimmed ? Qt.darker(root.bar.foreground, 1.45) : root.bar.foreground)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: wsCell.assignedHere
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (wsCell.mon) root.toggleWorkspaceAssignment(wsCell.mon, wsCell.wid) }
                      }
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: {
                  var ids = root.unassignedWorkspaceIds()
                  if (!ids.length) return "All 1–10 assigned."
                  if (ids.length === 10) return "No workspaces assigned — they show on the screen where they currently live."
                  return "Unassigned: " + ids.map(Model.workspaceDigit).join(", ")
                    + " — still shown on the screen where they live."
                }
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Split evenly"
                fontSize: Style.font.caption
                fontFamily: root.bar.fontFamily
                foreground: root.bar.foreground
                bordered: true
                horizontalPadding: Style.space(10)
                verticalPadding: Style.space(4)
                onClicked: root.autoSplitWorkspaces()
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
                    text: {
                      var cap = Number(root.selected && root.selected.bitdepthCapable)
                      var live = Model.scanoutLabel(root.selected)
                      if (cap === 8)
                        return live + ". EDID reports 8-bit; 10-bit may still work on DisplayPort."
                      return live + ". Hyprland output is 8-bit or 10-bit. Use 8-bit if screen capture fails."
                    }
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Dropdown {
                  width: parent.width
                  label: "WIDE COLOR"
                  showLabel: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  value: root.selected ? String(Number(root.selected.supportsWideColor) || 0) : "0"
                  options: root.wideColorOptions
                  onChanged: function(v) { root.setWideColor(v) }
                }

                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  text: "Auto follows EDID BT.2020. Force treats this panel as wide-gamut if EDID is wrong. Off blocks wide colour even when EDID claims it."
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Dropdown {
                  width: parent.width
                  label: "COLOR PRESET"
                  showLabel: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  value: root.selected ? String(root.selected.cm || "srgb") : "srgb"
                  options: root.hdrCmOptions
                  onChanged: function(v) { root.setHdrCm(v) }
                }

                Dropdown {
                  width: parent.width
                  label: "SDR TRANSFER"
                  showLabel: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  value: root.selected ? String(root.selected.sdrEotf || "default") : "default"
                  options: root.sdrEotfOptions
                  onChanged: function(v) { root.setSdrEotf(v) }
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

                  ScreensSlider {
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
                    implicitHeight: Math.max(sdrSatHeader.implicitHeight, sdrSatValue.implicitHeight)

                    PanelSectionHeader {
                      id: sdrSatHeader
                      text: "SDR SATURATION"
                      foreground: root.bar.foreground
                      fontFamily: root.bar.fontFamily
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: sdrSatValue
                      text: {
                        var n = root.selected ? Number(root.selected.sdrSaturation) : 1.0
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

                  ScreensSlider {
                    width: parent.width
                    bar: root.bar
                    minimum: 0.5
                    maximum: 2.0
                    step: 0.05
                    value: root.selected && isFinite(Number(root.selected.sdrSaturation)) && Number(root.selected.sdrSaturation) > 0
                      ? Number(root.selected.sdrSaturation) : 1.0
                    onMoved: function(v) { root.setSdrSaturation(v) }
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

                  ScreensSlider {
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

                  ScreensSlider {
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
              visible: root.selectedHdrOk && Model.hdrModeOf(root.selected) === 0
              width: parent.width
              label: "COLOR PRESET"
              showLabel: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              value: root.selected ? String(root.selected.cm || "srgb") : "srgb"
              options: root.sdrCmOptions
              onChanged: function(v) { root.setHdrCm(v) }
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

              ScreensSlider {
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

              Toggle {
                visible: root.enabledCount > 1
                width: parent.width
                label: "All monitors"
                description: "Set the same brightness on every connected display"
                checked: root.allMonitorsBrightness
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: root.allMonitorsBrightness = !root.allMonitorsBrightness
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Item {
                width: parent.width
                implicitHeight: Math.max(nightlightHeader.implicitHeight, nightlightRow.implicitHeight)

                PanelSectionHeader {
                  id: nightlightHeader
                  text: "NIGHT LIGHT"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                  id: nightlightRow
                  spacing: Style.space(8)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: root.nightlightEnabled
                      ? (Math.round(nightlightSlider.dragging ? nightlightSlider.liveValue : root.nightlightTemp) + "K")
                      : "OFF"
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  ToggleSwitch {
                    checked: root.nightlightEnabled
                    foreground: root.bar.foreground
                    onToggled: root.setNightlightEnabled(!root.nightlightEnabled)
                  }
                }
              }

              ScreensSlider {
                id: nightlightSlider
                width: parent.width
                bar: root.bar
                minimum: 1500
                maximum: 6500
                step: 50
                value: root.nightlightTemp
                integer: true
                onMoved: function(v) { root.previewNightlight(v) }
                onReleased: function(v) {
                  nightlightDebounce.stop()
                  root.setNightlight(v)
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

              ScreensSlider {
                id: textSizeSlider
                width: parent.width
                bar: root.bar
                minimum: 0
                maximum: root.textSizeStops.length - 1
                step: 1
                integer: true
                tickCount: root.textSizeStops.length
                value: root.currentTextIndex()
                onMoved: function(v) { root.setTextSize(root.textSizeStops[Math.round(v)]) }
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Remembered per display. Omarchy only has one desk font, so Apply uses this display's size for shell, GTK, and terminals. Scale below is truly per output."
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Column {
              id: scaleSection
              width: parent.width
              spacing: Style.space(4)

              Item {
                width: parent.width
                implicitHeight: Math.max(scaleHeader.implicitHeight, scaleValue.implicitHeight)

                PanelSectionHeader {
                  id: scaleHeader
                  text: "SCALE"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: scaleValue
                  text: Model.formatScale(root.selected ? root.selected.scale : 1) + "×"
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              ScreensSlider {
                width: parent.width
                bar: root.bar
                minimum: 1.0
                maximum: 4.0
                step: 0.01
                value: root.selected && Number(root.selected.scale) > 0 ? Number(root.selected.scale) : 1
                onMoved: function(v) { root.setScale(v) }
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
                    active: root.selected && Math.abs(Number(root.selected.scale) - Number(modelData)) < 0.005
                    onClicked: root.setScale(modelData, true)
                  }
                }
              }

              Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !!(root.selected)
                text: Model.scaleIsSharp(root.selected, root.selected ? root.selected.scale : 1)
                  ? "This output only. Whole-pixel scale — sharp."
                  : "This output only. Logical size is not whole pixels — may look soft. Try 1.25 or 1.33."
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
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

      Rectangle {
        id: applyDock
        visible: root.layoutDirty || root.pendingConfirm
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: root.bar && root.bar.background !== undefined ? root.bar.background : Color.background
        height: applyDockCol.implicitHeight + Style.space(16)

        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: 1
          color: Util.alpha(root.bar.foreground, 0.16)
        }

        Column {
          id: applyDockCol
          width: parent.width
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(8)
          spacing: Style.space(6)

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.pendingConfirm
              ? ("Keep this layout? Reverting in " + root.revertLeft + "s")
              : "Apply to preview on the displays. Undo throws the panel changes away."
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              visible: !root.pendingConfirm
              width: (parent.width - parent.spacing) / 2
              text: "Apply"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              active: true
              tooltipText: "Preview on the displays. Reverts in 20 seconds unless you Keep."
              onClicked: root.applyDraft()
            }

            Button {
              visible: !root.pendingConfirm
              width: (parent.width - parent.spacing) / 2
              text: "Undo"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              tooltipText: "Throw away panel changes and restore the last live layout."
              onClicked: root.undoDraft()
            }

            Button {
              visible: root.pendingConfirm
              width: (parent.width - parent.spacing) / 2
              text: "Keep"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              active: true
              onClicked: root.keepLayout()
            }

            Button {
              visible: root.pendingConfirm
              width: (parent.width - parent.spacing) / 2
              text: "Revert"
              fontSize: Style.font.caption
              fontFamily: root.bar.fontFamily
              foreground: root.bar.foreground
              bordered: true
              onClicked: root.revertLayout()
            }
          }
        }
      }
    }
    }

  QtObject {
    id: layoutMenuOwner
    function close() { root.layoutMenuOpen = false }
  }

  Item {
    id: layoutMenuDummy
    width: 1
    height: 1
    visible: false
  }

  WorkspaceLayoutMenu {
    anchorItem: root.layoutMenuAnchor || layoutMenuDummy
    bar: root.bar
    owner: layoutMenuOwner
    open: root.layoutMenuOpen && !!root.layoutMenuAnchor
    workspaceId: root.layoutMenuWorkspace
    currentLayout: String(root.workspaceLayouts[String(root.layoutMenuWorkspace)] || "tile")
    onChosen: function(mode) { root.setWorkspaceLayout(root.layoutMenuWorkspace, mode) }
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
