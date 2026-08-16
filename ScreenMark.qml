import QtQuick
import qs.Commons

// Two aspect-true tiles. Distinct from stock Display's 󰍹 / 󰍺.
Item {
  id: root
  property color foreground: Color.foreground
  implicitWidth: Style.font.icon
  implicitHeight: Style.font.icon

  Rectangle {
    width: parent.width * 0.64
    height: parent.height * 0.70
    x: 0
    y: parent.height * 0.15
    radius: Math.max(1, Style.cornerRadius > 0 ? 1.5 : 0)
    color: root.foreground
  }
  Rectangle {
    width: parent.width * 0.30
    height: parent.height * 0.46
    x: parent.width * 0.70
    y: parent.height * 0.27
    radius: Math.max(1, Style.cornerRadius > 0 ? 1.5 : 0)
    color: root.foreground
    opacity: 0.78
  }
}
