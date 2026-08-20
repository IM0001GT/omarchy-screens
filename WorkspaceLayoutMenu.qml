import QtQuick
import qs.Commons
import qs.Ui

PopupCard {
  id: root
  property int workspaceId: 0
  property string currentLayout: "tile"
  signal chosen(string mode)

  contentWidth: fittedContentWidth(Style.space(220))
  contentHeight: fittedContentHeight(menuCol.implicitHeight)

  readonly property var modes: [
    { value: "tile", label: "Tile", hint: "Dwindle tiling" },
    { value: "scroll", label: "Scroll", hint: "Side-by-side columns" },
    { value: "float", label: "Float", hint: "Every window floats" }
  ]

  Column {
    id: menuCol
    width: parent.width
    spacing: Style.space(6)

    Text {
      width: parent.width
      text: "Workspace " + (root.workspaceId === 10 ? "0" : String(root.workspaceId))
      color: root.bar ? root.bar.foreground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: "Applies only to this workspace."
      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: root.modes

      Button {
        required property var modelData
        width: menuCol.width
        text: modelData.label
        fontSize: Style.font.caption
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        foreground: root.bar ? root.bar.foreground : Color.foreground
        bordered: true
        active: root.currentLayout === modelData.value
        tooltipText: modelData.hint
        onClicked: root.chosen(modelData.value)
      }
    }
  }
}
