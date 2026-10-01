import QtQuick
import qs.Ui

// The shell dropdown writes its value when a row is picked, which drops the
// caller's binding. modelValue is put back after that pick, and again on Revert.
Dropdown {
  id: box

  property string modelValue: ""

  Binding {
    target: box
    property: "value"
    value: box.modelValue
  }
}
