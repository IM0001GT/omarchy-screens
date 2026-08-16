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
      hdrCapable: m.hdrCapable,
      vrrCapable: m.vrrCapable,
      logicalW: m.logicalW,
      logicalH: m.logicalH,
      mode: m.mode,
      resolutions: m.resolutions,
      physicalW: m.physicalW,
      physicalH: m.physicalH,
      identity: m.identity,
      mirror: m.mirror || ""
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
  var list = enabledOnly(monitors)
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
  var list = enabledOnly(monitors)
  if (!list.length) return monitors
  var minX = list[0].x
  var minY = list[0].y
  for (var i = 1; i < list.length; i++) {
    minX = Math.min(minX, list[i].x)
    minY = Math.min(minY, list[i].y)
  }
  if (minX === 0 && minY === 0) return monitors
  for (var j = 0; j < monitors.length; j++) {
    if (!monitors[j].enabled) continue
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
      enabled: !!m.enabled,
      identity: m.identity,
      description: m.description,
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
  var res = resolutionOf(mon.mode)
  if (res) bits.push(res.replace("x", "×"))
  var hz = Number(mon.refresh)
  if (isFinite(hz) && hz > 0) bits.push(Math.round(hz) + " Hz")
  if (mon.hdr) bits.push("HDR")
  if (mon.vrr) bits.push("VRR")
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

if (typeof module !== "undefined") {
  module.exports = {
    clone: clone,
    snapMove: snapMove,
    normalizeOrigin: normalizeOrigin,
    applyPayload: applyPayload,
    pickMode: pickMode,
    heroStatus: heroStatus
  }
}
