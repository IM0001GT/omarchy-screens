import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

KeyboardPanel {
  id: root
  property int workspaceId: 0
  property string currentLayout: "tile"
  property string workspaceName: ""
  property string workspaceIcon: ""
  property bool pickerOpen: false
  property string pickedIcon: ""
  signal chosen(string mode)
  signal labeled(string name, string icon)

  focusTarget: nameField
  contentWidth: fittedContentWidth(Style.space(280))
  contentHeight: fittedContentHeight(menuCol.implicitHeight)

  readonly property var modes: [
    { value: "tile", label: "Tile", hint: "Dwindle tiling" },
    { value: "scroll", label: "Scroll", hint: "Side-by-side columns" },
    { value: "float", label: "Float", hint: "Every window floats" }
  ]
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function tint(alpha) {
    return Qt.rgba(root.fg.r, root.fg.g, root.fg.b, alpha)
  }

  function glyphAt(i) {
    if (i === 0) return ""
    return Model.workspacePresetGlyph(i - 1)
  }

  function emitLabel() {
    root.labeled(nameField.text.trim(), root.pickedIcon)
  }

  function flush() {
    root.emitLabel()
  }

  function syncFields() {
    nameField.text = root.workspaceName
    root.pickedIcon = root.workspaceIcon
    root.pickerOpen = false
    Qt.callLater(function() {
      if (!root.open) return
      nameField.forceActiveFocus()
      nameField.selectAll()
    })
  }

  onOpenChanged: {
    if (!open) {
      root.pickerOpen = false
      return
    }
    root.syncFields()
  }

  Column {
    id: menuCol
    width: parent.width
    spacing: Style.space(6)

    Text {
      width: parent.width
      text: "Workspace " + (root.workspaceId === 10 ? "0" : String(root.workspaceId))
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Row {
      width: parent.width
      spacing: Style.space(6)

      Button {
        id: iconBtn
        width: Style.space(36)
        text: root.pickedIcon !== "" ? root.pickedIcon
          : (root.workspaceId === 10 ? "0" : String(root.workspaceId))
        fontSize: Style.font.icon
        fontFamily: root.fontFamily
        foreground: root.fg
        bordered: true
        active: root.pickerOpen
        tooltipText: root.pickerOpen ? "Hide icons" : "Pick an icon"
        onClicked: root.pickerOpen = !root.pickerOpen
      }

      TextField {
        id: nameField
        width: parent.width - iconBtn.width - parent.spacing
        placeholderText: "Name, leave empty to clear"
        foreground: root.fg
        verticalPadding: Style.space(4)
        onAccepted: root.emitLabel()
        Keys.onEscapePressed: root.close()
      }
    }

    Grid {
      id: presets
      visible: root.pickerOpen
      width: parent.width
      columns: 8
      spacing: Style.space(2)
      readonly property real cell: Math.floor((width - spacing * (columns - 1)) / columns)
      readonly property int count: Model.workspacePresetCount() + 1

      Repeater {
        model: presets.count

        Rectangle {
          required property int index
          readonly property string glyph: root.glyphAt(index)
          readonly property bool clears: index === 0
          readonly property bool chosen: root.pickedIcon === glyph

          width: presets.cell
          height: presets.cell
          radius: Style.cornerRadius
          color: chosen ? root.tint(0.22)
            : (hover.hovered ? root.tint(0.10) : "transparent")

          Text {
            anchors.centerIn: parent
            text: parent.clears ? "\u00d7" : parent.glyph
            color: parent.clears ? Qt.darker(root.fg, 1.5) : root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
          }

          HoverHandler { id: hover }
          TapHandler {
            onTapped: {
              root.pickedIcon = parent.glyph
              root.emitLabel()
            }
          }
        }
      }
    }

    PanelSeparator { foreground: root.fg }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Name, icon, and layout apply only to this workspace."
      color: Qt.darker(root.fg, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.modes

      Button {
        required property var modelData
        width: menuCol.width
        text: modelData.label
        fontSize: Style.font.caption
        fontFamily: root.fontFamily
        foreground: root.fg
        bordered: true
        active: root.currentLayout === modelData.value
        tooltipText: modelData.hint
        onClicked: root.chosen(modelData.value)
      }
    }
  }
}
