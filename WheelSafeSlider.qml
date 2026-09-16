import QtQuick
import qs.Commons

// Plugin-local slider. Drag or focused arrow keys change the value; the
// wheel always scrolls the panel instead.
Item {
  id: root

  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property color trackColor: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "#333"
  property color fillColor: bar ? bar.foreground : Color.foreground
  property color knobColor: bar ? bar.foreground : Color.foreground
  property bool dragging: false
  property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
  property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
  property real liveValue: value
  property int tickCount: 0
  property color tickColor: bar ? bar.background : Color.background
  property bool keyAdjust: true

  onValueChanged: if (!dragging) liveValue = value

  signal moved(real value)
  signal released(real value)
  signal rightClicked()

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.md)
  activeFocusOnTab: true

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool _hot: mouseArea.containsMouse || root.dragging || root.activeFocus

  function clampValue(v) {
    var next = Math.max(root.minimum, Math.min(root.maximum, v))
    if (root.integer) next = Math.round(next)
    return next
  }

  function applyValue(next, commit) {
    next = root.clampValue(next)
    root.liveValue = next
    root.moved(next)
    if (commit) root.released(next)
  }

  function nudge(dir) {
    root.applyValue(root.liveValue + dir * root.step, true)
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Down || event.key === Qt.Key_Minus) {
      root.nudge(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Up
        || event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
      root.nudge(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Home) {
      root.applyValue(root.minimum, true)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_End) {
      root.applyValue(root.maximum, true)
      event.accepted = true
    }
  }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.trackHeight
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors.verticalCenter: track.verticalCenter
    anchors.left: track.left
    height: track.height
    radius: track.radius
    color: root.fillColor
    width: track.width * root.progress

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  Repeater {
    model: root.tickCount > 1 ? root.tickCount : 0
    Rectangle {
      required property int index
      width: Math.max(1, Style.space(2))
      height: root.trackHeight + Style.space(4)
      radius: 1
      color: root.tickColor
      anchors.verticalCenter: track.verticalCenter
      x: Math.max(0, Math.min(track.width - width,
                              track.width * (index / (root.tickCount - 1)) - width / 2))
    }
  }

  Rectangle {
    id: knob
    width: root.knobSize
    height: root.knobSize
    radius: root.knobSize / 2
    color: root.knobColor
    border.color: root.bar ? root.bar.background : "#101315"
    border.width: Math.max(1, Style.space(2))
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * root.progress - width / 2))
    scale: root._hot ? 1.15 : 1.0

    Behavior on x {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function valueFromX(x) {
      var clamped = Math.max(0, Math.min(track.width, x))
      var raw = root.minimum + (clamped / track.width) * root.range
      if (root.integer) raw = Math.round(raw)
      return Math.max(root.minimum, Math.min(root.maximum, raw))
    }

    onPressed: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.forceActiveFocus()
      root.dragging = true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.rightClicked()
    }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onReleased: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = false
      root.released(root.liveValue)
      root.liveValue = root.value
    }
    onWheel: function(wheel) {
      wheel.accepted = false
    }
  }
}
