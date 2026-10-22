import QtQuick
import QtQuick.Controls as QQC
import Quickshell.Io
import qs.Commons
import qs.Ui

// Plain-text line. Paste is read outside the shell, capped, and given one
// second. The field does not use Qt's native clipboard read.
QQC.TextArea {
  id: root
  property color foreground: Color.foreground
  property color accent: Color.accent
  property int maximumLength: 48
  property real horizontalPadding: Style.spacing.controlPaddingX
  property real verticalPadding: Style.space(4)
  signal accepted()

  readonly property var borderSpec: Border.controlSpec(
    activeFocus ? "focus" : (hovered ? "hover-cursor" : "normal"),
    foreground, accent)

  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  selectByMouse: true
  activeFocusOnTab: true
  clip: true
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  color: foreground
  selectionColor: Style.selectionFillFor(foreground, accent)
  selectedTextColor: foreground
  placeholderTextColor: Qt.darker(foreground, 1.6)
  leftPadding: horizontalPadding + Border.left(borderSpec)
  rightPadding: horizontalPadding + Border.right(borderSpec)
  topPadding: verticalPadding + Border.top(borderSpec)
  bottomPadding: verticalPadding + Border.bottom(borderSpec)
  implicitHeight: font.pixelSize + topPadding + bottomPadding

  background: BorderSurface {
    color: Style.controlFill(root.activeFocus, root.hovered, root.foreground, root.accent)
    borderSpec: root.borderSpec
    radius: Style.cornerRadius
  }

  QQC.ContextMenu.menu: null
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.matches(StandardKey.Paste)) {
      root.boundedPaste(false)
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.accepted()
      event.accepted = true
    }
  }

  onTextChanged: {
    if (text.length > maximumLength)
      text = text.slice(0, maximumLength)
  }

  function boundedPaste(primary) {
    if (readOnly || !enabled || reader.running) return
    reader.previousText = text
    reader.start = selectionStart
    reader.end = selectionEnd
    reader.cursor = cursorPosition
    var script = decodeURIComponent(
      Qt.resolvedUrl("clipboard_read.py").toString().replace(/^file:\/\//, ""))
    var cap = Math.max(1, Math.min(maximumLength * 4, 1024))
    reader.command = ["python3", script, String(cap), primary ? "primary" : "clipboard"]
    reader.running = true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    cursorShape: Qt.IBeamCursor
    onPressed: function(mouse) {
      root.forceActiveFocus()
      root.cursorPosition = root.positionAt(mouse.x, mouse.y)
    }
    onClicked: root.boundedPaste(true)
  }

  Process {
    id: reader
    property string previousText: ""
    property int start: 0
    property int end: 0
    property int cursor: 0
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0 || !root.activeFocus || root.readOnly || !root.enabled) return
      if (root.text !== reader.previousText || root.cursorPosition !== reader.cursor) return
      if (root.selectionStart !== reader.start || root.selectionEnd !== reader.end) return
      var value = ""
      try {
        value = JSON.parse(output.text)
      } catch (e) {
        return
      }
      if (typeof value !== "string") return
      value = value.replace(/[\r\n\u2028\u2029]+/g, " ")
      var room = root.maximumLength - (root.length - (reader.end - reader.start))
      if (room < 1) return
      value = value.slice(0, room)
      if (!value) return
      root.remove(reader.start, reader.end)
      root.insert(reader.start, value)
      root.cursorPosition = reader.start + value.length
    }
  }
}
