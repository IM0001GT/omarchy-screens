function clone(monitors) {
  var out = []
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    out.push({
      name: m.name,
      description: m.description,
      make: m.make,
      model: m.model,
      label: m.label,
      enabled: m.enabled,
      focused: m.focused,
      width: m.width,
      height: m.height,
      refresh: m.refresh,
      x: m.x,
      y: m.y,
      scale: m.scale,
      transform: m.transform,
      vrr: m.vrr,
      cm: m.cm,
      format: m.format,
      hdr: m.hdr,
      hdrMode: m.hdrMode,
      hdrCapable: m.hdrCapable,
      vrrCapable: m.vrrCapable,
      bitdepth: m.bitdepth,
      bitdepthCapable: m.bitdepthCapable,
      sdrMinLuminance: m.sdrMinLuminance,
      sdrMaxLuminance: m.sdrMaxLuminance,
      sdrBrightness: m.sdrBrightness,
      wideGamut: !!m.wideGamut,
      minLuminance: m.minLuminance,
      maxLuminance: m.maxLuminance,
      maxAvgLuminance: m.maxAvgLuminance,
      logicalW: m.logicalW,
      logicalH: m.logicalH,
      mode: m.mode,
      resolutions: m.resolutions,
      physicalW: m.physicalW,
      physicalH: m.physicalH,
      identity: m.identity,
      mirror: m.mirror || "",
      secondaryGpu: !!m.secondaryGpu
    })
  }
  return out
}

function enabledOnly(monitors) {
  var out = []
  for (var i = 0; i < monitors.length; i++) {
    if (monitors[i] && monitors[i].enabled) out.push(monitors[i])
  }
  return out
}

function indexByName(monitors, name) {
  for (var i = 0; i < monitors.length; i++) {
    if (monitors[i].name === name) return i
  }
  return -1
}

function indexByIdentity(monitors, identity) {
  for (var i = 0; i < monitors.length; i++) {
    if (monitors[i].identity === identity) return i
  }
  return -1
}

function preferredIndex(monitors, barScreen, primary) {
  var i
  if (barScreen) {
    i = indexByName(monitors, barScreen)
    if (i >= 0) return i
  }
  if (primary) {
    i = indexByIdentity(monitors, primary)
    if (i >= 0) return i
  }
  for (i = 0; i < monitors.length; i++) {
    if (monitors[i].focused) return i
  }
  return monitors.length ? 0 : -1
}

function logicalW(m) {
  return Math.max(1, Number(m.logicalW) || 1)
}

function logicalH(m) {
  return Math.max(1, Number(m.logicalH) || 1)
}

function bounds(monitors) {
  var list = monitors || []
  if (!list.length) return { x: 0, y: 0, w: 1920, h: 1080 }
  var minX = list[0].x, minY = list[0].y
  var maxX = list[0].x + logicalW(list[0])
  var maxY = list[0].y + logicalH(list[0])
  for (var i = 1; i < list.length; i++) {
    var m = list[i]
    minX = Math.min(minX, m.x)
    minY = Math.min(minY, m.y)
    maxX = Math.max(maxX, m.x + logicalW(m))
    maxY = Math.max(maxY, m.y + logicalH(m))
  }
  return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) }
}

function overlaps(a, b) {
  return a.x < b.x + logicalW(b) && a.x + logicalW(a) > b.x
      && a.y < b.y + logicalH(b) && a.y + logicalH(a) > b.y
}

function resolveOverlap(moving, others) {
  var x = moving.x
  var y = moving.y
  var w = logicalW(moving)
  var h = logicalH(moving)
  for (var n = 0; n < 8; n++) {
    var hit = null
    for (var i = 0; i < others.length; i++) {
      var o = others[i]
      if (!o.enabled) continue
      var probe = { x: x, y: y, logicalW: w, logicalH: h }
      if (overlaps(probe, o)) { hit = o; break }
    }
    if (!hit) break
    var ow = logicalW(hit)
    var oh = logicalH(hit)
    var left = (x + w) - hit.x
    var right = (hit.x + ow) - x
    var top = (y + h) - hit.y
    var bottom = (hit.y + oh) - y
    var smallest = Math.min(left, right, top, bottom)
    if (smallest === left) x = hit.x - w
    else if (smallest === right) x = hit.x + ow
    else if (smallest === top) y = hit.y - h
    else y = hit.y + oh
  }
  return { x: x, y: y }
}

function snapMove(monitors, index, x, y, threshold) {
  var moving = monitors[index]
  if (!moving) return { x: x, y: y, guideX: null, guideY: null }
  var thresh = Math.max(24, Number(threshold) || 80)
  var centerThresh = Math.max(16, Math.min(36, Math.round(thresh * 0.33)))
  var w = logicalW(moving)
  var h = logicalH(moving)
  var bestX = { dist: thresh + 1, value: x, guide: null }
  var bestY = { dist: thresh + 1, value: y, guide: null }

  function considerX(value, dist, guide) {
    if (dist <= bestX.dist) {
      bestX = { dist: dist, value: value, guide: guide }
    }
  }
  function considerY(value, dist, guide) {
    if (dist <= bestY.dist) {
      bestY = { dist: dist, value: value, guide: guide }
    }
  }
  function considerCenterX(value, dist, guide) {
    if (dist <= centerThresh && dist <= bestX.dist) {
      bestX = { dist: dist, value: value, guide: guide }
    }
  }

  for (var i = 0; i < monitors.length; i++) {
    if (i === index || !monitors[i].enabled) continue
    var o = monitors[i]
    var ow = logicalW(o)
    var oh = logicalH(o)
    var candsX = [
      { value: o.x + ow, guide: o.x + ow },
      { value: o.x - w, guide: o.x },
      { value: o.x, guide: o.x },
      { value: o.x + ow - w, guide: o.x + ow }
    ]
    var candsY = [
      { value: o.y + oh, guide: o.y + oh },
      { value: o.y - h, guide: o.y },
      { value: o.y, guide: o.y },
      { value: o.y + oh - h, guide: o.y + oh }
    ]
    for (var c = 0; c < candsX.length; c++) {
      considerX(candsX[c].value, Math.abs(x - candsX[c].value), candsX[c].guide)
    }
    for (var d = 0; d < candsY.length; d++) {
      considerY(candsY[d].value, Math.abs(y - candsY[d].value), candsY[d].guide)
    }
    var above = Math.abs((y + h) - o.y)
    var below = Math.abs(y - (o.y + oh))
    if (Math.min(above, below) <= thresh) {
      var centered = o.x + (ow - w) / 2
      considerCenterX(centered, Math.abs(x - centered), o.x + ow / 2)
    }
  }

  var nx = bestX.dist <= thresh ? bestX.value : x
  var ny = bestY.dist <= thresh ? bestY.value : y
  var others = []
  for (var k = 0; k < monitors.length; k++) {
    if (k !== index) others.push(monitors[k])
  }
  var resolved = resolveOverlap({ x: nx, y: ny, logicalW: w, logicalH: h, enabled: true }, others)
  return {
    x: Math.round(resolved.x),
    y: Math.round(resolved.y),
    guideX: bestX.dist <= thresh ? bestX.guide : null,
    guideY: bestY.dist <= thresh ? bestY.guide : null
  }
}

function normalizeOrigin(monitors) {
  if (!monitors || !monitors.length) return monitors
  var minX = monitors[0].x
  var minY = monitors[0].y
  for (var i = 1; i < monitors.length; i++) {
    minX = Math.min(minX, monitors[i].x)
    minY = Math.min(minY, monitors[i].y)
  }
  if (minX === 0 && minY === 0) return monitors
  for (var j = 0; j < monitors.length; j++) {
    monitors[j].x -= minX
    monitors[j].y -= minY
  }
  return monitors
}

function applyPayload(monitors) {
  var out = []
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    out.push({
      name: m.name,
      description: m.description,
      mode: m.mode,
      x: Math.round(m.x),
      y: Math.round(m.y),
      scale: m.scale,
      transform: m.transform,
      vrr: m.vrr,
      hdr: !!m.hdr,
      hdrMode: m.hdrMode,
      bitdepth: m.bitdepth,
      cm: m.cm,
      sdrMinLuminance: m.sdrMinLuminance,
      sdrMaxLuminance: m.sdrMaxLuminance,
      sdrBrightness: m.sdrBrightness,
      minLuminance: m.minLuminance,
      maxLuminance: m.maxLuminance,
      enabled: !!m.enabled,
      identity: m.identity,
      mirror: m.mirror || ""
    })
  }
  return { monitors: out }
}

function resolutionOf(mode) {
  var m = String(mode || "").split("@")[0]
  return m
}

function refreshesFor(mon, resolution) {
  var res = resolution || resolutionOf(mon.mode)
  var list = mon.resolutions || []
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === res) return list[i].refreshes || []
  }
  return []
}

function resolutionOptions(mon) {
  var list = mon.resolutions || []
  var out = []
  for (var i = 0; i < list.length; i++) {
    out.push({ value: list[i].id, label: list[i].label })
  }
  return out
}

function refreshOptions(mon) {
  var list = refreshesFor(mon, resolutionOf(mon.mode))
  var out = []
  for (var i = 0; i < list.length; i++) {
    out.push({ value: list[i].id, label: list[i].label })
  }
  return out
}

function pickMode(mon, resolution, preferHz) {
  var list = refreshesFor(mon, resolution)
  if (!list.length) return mon.mode
  if (preferHz === undefined || preferHz === null) {
    var cur = String(mon.mode || "").split("@")[1]
    preferHz = parseFloat(cur)
  }
  var best = list[0]
  var bestDist = Infinity
  for (var i = 0; i < list.length; i++) {
    var d = Math.abs(list[i].refresh - preferHz)
    if (d < bestDist) { bestDist = d; best = list[i] }
  }
  return best.id
}

function heroStatus(mon, profileName) {
  if (!mon) return "No displays"
  var bits = []
  if (profileName) bits.push(profileName)
  if (!mon.enabled) bits.push("Off")
  var res = resolutionOf(mon.mode)
  if (res) bits.push(res.replace("x", "×"))
  var hz = Number(mon.refresh)
  if (isFinite(hz) && hz > 0) bits.push(Math.round(hz) + " Hz")
  if (Number(mon.hdrMode) === 1) bits.push("HDR Auto")
  else if (mon.hdr || Number(mon.hdrMode) === 2)
    bits.push(Number(mon.bitdepth) === 8 ? "HDR 8" : "HDR")
  if (Number(mon.vrr) === 1) bits.push("VRR")
  else if (Number(mon.vrr) === 2) bits.push("VRR FS")
  else if (Number(mon.vrr) === 3) bits.push("VRR GAME")
  return bits.length ? bits.join(" · ") : (mon.label || mon.name)
}

function mirrorOptions(monitors, selected) {
  var out = [{ value: "", label: "Off" }]
  if (!monitors) return out
  for (var i = 0; i < monitors.length; i++) {
    var m = monitors[i]
    if (!m || !m.enabled) continue
    if (selected && m.name === selected.name) continue
    out.push({ value: m.name, label: m.label || m.name })
  }
  return out
}

function hdrModeOf(mon) {
  var n = Number(mon && mon.hdrMode)
  if (n === 1 || n === 2) return n
  return (mon && mon.hdr) ? 2 : 0
}

function hdrDescription(mon) {
  if (!mon) return "Off"
  var mode = hdrModeOf(mon)
  if (mode === 0) return "Desktop stays SDR"
  var bits = Number(mon.bitdepth) === 8 ? "8-bit" : "10-bit"
  var cm = String(mon.cm || "") === "hdredid" ? "display" : "BT.2020"
  if (mode === 1) return "Fullscreen only · " + bits + " · " + cm
  return "Always on · " + bits + " · " + cm
}

function defaultHdrCm(mon) {
  return (mon && mon.wideGamut) ? "hdr" : "hdredid"
}

function defaultSdrBrightness(mon) {
  if (mon && mon.wideGamut) return 1.0
  var peak = Number(mon && mon.maxLuminance)
  if (isFinite(peak) && peak >= 600) return 1.0
  return 1.2
}

function clampBrightness(value) {
  var n = Number(value)
  if (!isFinite(n)) return 1
  return Math.max(1, Math.min(100, Math.round(n)))
}

function lastDisplayQuip(index) {
  var lines = [
    "Nice try",
    "Someone has to stay awake",
    "This one pays the rent",
    "The void isn't a display",
    "Can't leave you in the dark",
    "This screen has tenure",
    "No black hole today",
    "Keep the porch light on",
    "The desktop needs a home",
    "One window, minimum"
  ]
  var n = lines.length
  var i = Math.round(Number(index))
  if (!isFinite(i)) i = 0
  i = ((i % n) + n) % n
  return lines[i]
}

function brightnessName(percent) {
  var p = Math.round(percent)
  if (p >= 95) return "Sun blast"
  if (p >= 80) return "Solar flare"
  if (p >= 65) return "Golden hour"
  if (p >= 45) return "Even day"
  if (p >= 30) return "Soft glow"
  if (p >= 20) return "Lamp light"
  if (p >= 10) return "Candlelit"
  return "Night owl"
}

function defaultSdrPeak(mon) {
  var avg = Number(mon && mon.maxAvgLuminance)
  if (isFinite(avg) && avg >= 80 && avg <= 400) return Math.round(avg)
  var peak = Number(mon && mon.maxLuminance)
  if (isFinite(peak) && peak >= 80 && peak <= 400) return Math.round(peak)
  return 200
}

function splitCounts(n, total) {
  total = total || 10
  n = Math.round(Number(n) || 0)
  if (n <= 0) return []
  if (n >= total) {
    var padded = []
    for (var i = 0; i < n; i++) padded.push(i < total ? 1 : 0)
    return padded
  }
  var base = Math.floor(total / n)
  var extra = total % n
  var out = []
  for (var j = 0; j < n; j++) out.push(j < extra ? base + 1 : base)
  return out
}

function workspaceHosts(monitors, primary) {
  var hosts = []
  for (var i = 0; i < (monitors || []).length; i++) {
    var m = monitors[i]
    if (!m || !m.enabled || m.mirror) continue
    hosts.push(m)
  }
  hosts.sort(function(a, b) {
    var ap = primary && a.identity === primary ? 0 : 1
    var bp = primary && b.identity === primary ? 0 : 1
    if (ap !== bp) return ap - bp
    if (a.x !== b.x) return a.x - b.x
    if (a.y !== b.y) return a.y - b.y
    var an = a.name || "", bn = b.name || ""
    if (an < bn) return -1
    if (an > bn) return 1
    return 0
  })
  return hosts
}

function workspacePlan(monitors, primary) {
  var hosts = workspaceHosts(monitors, primary)
  var counts = splitCounts(hosts.length, 10)
  var n = 1
  var plan = []
  for (var i = 0; i < hosts.length; i++) {
    var count = counts[i] || 0
    var ids = []
    for (var k = 0; k < count; k++) ids.push(n + k)
    n += count
    plan.push({
      name: hosts[i].name || "",
      identity: hosts[i].identity || "",
      label: hosts[i].label || hosts[i].name || "",
      ids: ids,
      first: ids.length ? ids[0] : 0,
      last: ids.length ? ids[ids.length - 1] : 0
    })
  }
  return plan
}

function planForMonitor(plan, mon) {
  if (!plan || !mon) return null
  for (var i = 0; i < plan.length; i++) {
    if (plan[i].name === mon.name || (mon.identity && plan[i].identity === mon.identity))
      return plan[i]
  }
  return null
}

function workspaceId(id) {
  var text = String(id == null ? "" : id).trim()
  if (text !== "10" && !/^[1-9]$/.test(text)) return 0
  return parseInt(text, 10)
}

function workspaceDigit(id) {
  var n = workspaceId(id)
  if (!n) return ""
  if (n === 10) return "0"
  return String(n)
}

// Nerd Font codepoints for common workspace kinds. Same set as
// jankeesvw.workspace-name, checked against JetBrainsMono Nerd Font.
var workspacePresetIcons = [
  0xEAC4, 0xF120, 0xF06A9, 0xF040, 0xF02D, 0xF07B, 0xE69C,
  0xE8A4, 0xF01EE, 0xE217, 0xF232, 0xE820, 0xEB72, 0xF086, 0xF292,
  0xEC1B, 0xF03D, 0xF030, 0xF03E, 0xF1FC, 0xF11B, 0xF108, 0xF073,
  0xF017, 0xF002, 0xF188, 0xF080, 0xF1C0, 0xF233, 0xF0C2, 0xE712,
  0xF015, 0xF013, 0xF023, 0xF0C3, 0xF135, 0xF0F4, 0xF005, 0xEA71
]

function workspaceLabelOf(assignment, id) {
  var labels = (assignment && assignment.labels) ? assignment.labels : {}
  var entry = labels[String(id)]
  if (!entry || typeof entry !== "object") return { name: "", icon: "" }
  return {
    name: String(entry.name || ""),
    icon: String(entry.icon || "")
  }
}

function workspaceBarText(assignment, id, focused) {
  var icon = workspaceLabelOf(assignment, id).icon
  if (icon) return icon
  return focused ? "\uDB85\uDCFB" : workspaceDigit(id)
}

function workspacePresetCount() {
  return workspacePresetIcons.length
}

function workspacePresetGlyph(i) {
  if (i < 0 || i >= workspacePresetIcons.length) return ""
  return String.fromCodePoint(workspacePresetIcons[i])
}

function workspaceRangeLabel(first, last) {
  if (!first) return ""
  if (first === last) return workspaceDigit(first)
  return workspaceDigit(first) + "–" + workspaceDigit(last)
}

function layoutLabel(mode) {
  if (mode === "scroll") return "Scroll"
  if (mode === "float") return "Float"
  return "Tile"
}

function profileOptions(profiles) {
  var out = []
  if (!profiles) return out
  for (var i = 0; i < profiles.length; i++) {
    var p = profiles[i]
    if (!p || !p.name) continue
    var n = Number(p.count) || 0
    out.push({
      value: p.name,
      label: n > 0 ? (p.name + " · " + n + (n === 1 ? " screen" : " screens")) : p.name
    })
  }
  return out
}

function clampBarDim(value) {
  var n = Number(value)
  if (!isFinite(n)) return 45
  if (n < 0) return 0
  if (n > 100) return 100
  return Math.round(n)
}

function normalizeBarCare(raw) {
  var src = raw || {}
  return {
    enabled: !!src.enabled,
    dim: clampBarDim(src.dim),
    hoverLift: src.hoverLift !== false
  }
}

function barOpacityFor(care, state) {
  var cfg = normalizeBarCare(care)
  var st = state || {}
  if (!cfg.enabled) return 1
  if (st.barHidden) return 1
  if (st.hovered && cfg.hoverLift) return 1
  var opacity = 1 - cfg.dim / 100
  if (opacity < 0) opacity = 0
  return opacity
}

if (typeof module !== "undefined") {
  module.exports = {
    clone: clone,
    snapMove: snapMove,
    normalizeOrigin: normalizeOrigin,
    applyPayload: applyPayload,
    pickMode: pickMode,
    heroStatus: heroStatus,
    hdrModeOf: hdrModeOf,
    hdrDescription: hdrDescription,
    defaultHdrCm: defaultHdrCm,
    defaultSdrBrightness: defaultSdrBrightness,
    defaultSdrPeak: defaultSdrPeak,
    clampBrightness: clampBrightness,
    brightnessName: brightnessName,
    lastDisplayQuip: lastDisplayQuip,
    splitCounts: splitCounts,
    workspaceHosts: workspaceHosts,
    workspacePlan: workspacePlan,
    planForMonitor: planForMonitor,
    workspaceId: workspaceId,
    workspaceDigit: workspaceDigit,
    workspacePresetIcons: workspacePresetIcons,
    workspaceLabelOf: workspaceLabelOf,
    workspaceBarText: workspaceBarText,
    workspacePresetCount: workspacePresetCount,
    workspacePresetGlyph: workspacePresetGlyph,
    workspaceRangeLabel: workspaceRangeLabel,
    layoutLabel: layoutLabel,
    clampBarDim: clampBarDim,
    normalizeBarCare: normalizeBarCare,
    barOpacityFor: barOpacityFor
  }
}
