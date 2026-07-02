// Standard bar button: hover-Rectangle + content slot + MouseArea that
// toggles a Panels entry on click. Collapses the ~10-line boilerplate
// (hover rect + Text with font triple + MouseArea + Panels.toggle) that
// was duplicated verbatim across 8 bar widgets.
//
// Caller supplies either `label` (string) or content children (which
// land in the default slot — e.g. an icon, a row of dots, an Image).
//
//   WidgetButton { label: "(" + count + ")"; panel: Panels.notifications }
//   WidgetButton { panel: Panels.launcher; Image { ... } }
//
// Right-click support: set `rightClicked` to a `(mouse) => {...}` handler
// and `acceptRightClick: true`.

import "."
import "../util"
import QtQuick

Item {
    id: root

    // The Panels constant to toggle on click. Use Panels.none for a
    // button that handles its own click via `clicked`.
    property string panel: ""

    // Optional text label. If non-empty, a themed Text is rendered.
    property string label: ""

    // Override the label's color (e.g. BatteryWidget color-codes by level).
    property color labelColor: Colors.foreground

    // Default slot for arbitrary content (icon, dots, image, etc.).
    default property alias content: contentSlot.data

    // Set true and provide rightClicked to receive right-button clicks.
    property bool acceptRightClick: false

    // Click handlers. `(mouse) => {...}` form for parity with Qt 6.
    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal wheeled(var wheel)

    width: label !== "" ? labelItem.implicitWidth + 2 * Theme.margin : 30
    height: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        color: mouseArea.containsMouse
            ? Qt.alpha(Colors.foreground, Theme.alphaHover)
            : "transparent"
    }

    ThemeText {
        id: labelItem
        anchors.centerIn: parent
        text: root.label
        visible: root.label !== ""
        color: root.labelColor
    }

    Item {
        id: contentSlot
        anchors.fill: parent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.acceptRightClick
            ? (Qt.LeftButton | Qt.RightButton)
            : Qt.LeftButton
        onClicked: mouse => {
            if (root.acceptRightClick && mouse.button === Qt.RightButton) {
                root.rightClicked(mouse)
            } else {
                if (root.panel !== "") Panels.toggle(root.panel)
                root.clicked(mouse)
            }
        }
        onWheel: wheel => root.wheeled(wheel)
    }
}
