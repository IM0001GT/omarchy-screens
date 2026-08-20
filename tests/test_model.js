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

console.log("ok")
