const assert = require("assert")
const Model = require("../Model.js")

assert.deepStrictEqual(Model.splitCounts(2), [5, 5])
assert.deepStrictEqual(Model.splitCounts(3), [4, 3, 3])
assert.deepStrictEqual(Model.splitCounts(9), [2, 1, 1, 1, 1, 1, 1, 1, 1])
assert.deepStrictEqual(Model.splitCounts(1), [10])
assert.strictEqual(Model.splitCounts(3).reduce((a, b) => a + b, 0), 10)

const left = { name: "DP-4", identity: "desc:HYC", enabled: true, x: 0, y: 0, label: "HYC", mirror: "" }
const right = { name: "HDMI-A-1", identity: "desc:LG", enabled: true, x: 2560, y: 0, label: "LG", mirror: "" }
const plan = Model.workspacePlan([left, right], "desc:LG")
assert.strictEqual(plan[0].name, "HDMI-A-1")
assert.deepStrictEqual(plan[0].ids, [1, 2, 3, 4, 5])
assert.deepStrictEqual(plan[1].ids, [6, 7, 8, 9, 10])
assert.strictEqual(Model.workspaceRangeLabel(1, 5), "1–5")
assert.strictEqual(Model.workspaceId("3"), 3)
assert.strictEqual(Model.workspaceId("10"), 10)
assert.strictEqual(Model.workspaceId("0"), 0)
assert.strictEqual(Model.workspaceId("11"), 0)
assert.strictEqual(Model.workspaceId('1"; hl.dispatch(1)'), 0)
assert.strictEqual(Model.workspaceId("nope"), 0)
assert.strictEqual(Model.workspaceDigit(10), "0")
assert.strictEqual(Model.workspaceDigit("nope"), "")
assert.strictEqual(Model.layoutLabel("scroll"), "Scroll")
assert.strictEqual(Model.planForMonitor(plan, left).first, 6)

const careOff = Model.normalizeBarCare(null)
assert.strictEqual(careOff.enabled, false)
assert.strictEqual(careOff.dim, 45)
assert.strictEqual(Model.barOpacityFor(careOff, {}), 1)
assert.ok(Model.barOpacityFor({ enabled: true, dim: 40 }, {}) < 0.7)
assert.ok(Model.barOpacityFor({ enabled: true, dim: 40 }, { hovered: true }) === 1)
assert.ok(Model.barOpacityFor({ enabled: true, dim: 40, hoverLift: false }, { hovered: true }) < 1)
assert.strictEqual(Model.barOpacityFor({ enabled: true, dim: 100 }, {}), 0)
assert.strictEqual(Model.clampBarDim(140), 100)
assert.strictEqual(Model.formatScale(1.33), "1.33")
assert.strictEqual(Model.formatScale(1.5), "1.5")
assert.ok(Model.scaleIsSharp({ width: 3840, height: 2160 }, 1.25))
assert.ok(!Model.scaleIsSharp({ width: 1920, height: 1080 }, 1.4))
assert.ok(Model.hdrDescription({ hdrMode: 2, bitdepth: 10, cm: "hdr" }).indexOf("10-bit") >= 0)
assert.notStrictEqual(Model.defaultSdrPeak({ maxLuminance: 604, maxAvgLuminance: 604 }), 200)
assert.ok(Model.defaultSdrPeak({ maxLuminance: 604, maxAvgLuminance: 604 }) >= 400)
assert.strictEqual(Model.defaultSdrPeak({ maxAvgLuminance: 250 }), 250)
assert.ok(Model.scanoutLabel({ format: "XBGR2101010" }).indexOf("10-bit") >= 0)
assert.ok(Model.scanoutLabel({ format: "XBGR16161616F" }).indexOf("16-bit float") >= 0)

const row = [
  { name: "left", enabled: true, mode: "1920x1080", width: 1920, height: 1080, scale: 1, transform: 0, x: 0, y: 0, logicalW: 1920, logicalH: 1080 },
  { name: "right", enabled: true, mode: "1920x1080", width: 1920, height: 1080, scale: 1, transform: 0, x: 1920, y: 0, logicalW: 1920, logicalH: 1080 },
]
row[0].scale = 2
Model.reflowAfterResize(row, 0, 1920, 1080)
assert.strictEqual(row[0].logicalW, 960)
assert.strictEqual(row[1].x, 960)

function mon(name, x, y, w, h) {
  return { name: name, enabled: true, x: x, y: y, logicalW: w, logicalH: h }
}

const desk = [
  mon("bottom", 0, 800, 1920, 1080),
  mon("top", 200, 0, 1280, 800),
]

const alreadyCentered = Model.snapMove(desk, 1, 320, 0, 96)
assert.strictEqual(alreadyCentered.x, 320)
const aBitOff = Model.snapMove(desk, 1, 340, 0, 96)
assert.strictEqual(aBitOff.x, 320)
assert.strictEqual(aBitOff.guideX, 960)

const stayOff = Model.snapMove(desk, 1, 500, 0, 96)
assert.strictEqual(stayOff.x, 500)

const pair = [
  mon("left", 0, 0, 1920, 1080),
  mon("right", 1920, 150, 1280, 800),
]
const beside = Model.snapMove(pair, 1, 1920, 150, 96)
assert.strictEqual(beside.x, 1920)
assert.strictEqual(beside.y, 150)

console.log("ok")
