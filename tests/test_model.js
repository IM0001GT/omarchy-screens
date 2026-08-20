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
assert.strictEqual(Model.workspaceDigit(10), "0")
assert.strictEqual(Model.layoutLabel("scroll"), "Scroll")
assert.strictEqual(Model.planForMonitor(plan, left).first, 6)

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
