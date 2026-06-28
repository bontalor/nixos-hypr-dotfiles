// Shared scaffold for two-pane (sections list + content) panels.
//
// Provides the standard FloatingWindow + sidebar + content Flickable + section
// header bar, plus J/K/Tab keyboard navigation in the common
// "list of selectable rows per section" pattern.
//
// Panels override behavior via property bindings:
//   - currentModelLength: function() -> int   (rows in the current section)
// And via signals:
//   - shown()            emitted when the panel becomes visible (after reset)
//   - deviceActivated(i) emitted on Enter when a row is selected
//   - keyPressed(event)  every keypress (use useDefaultKeys:false to fully take over)
//   - sectionChanged(i)  emitted when selSection changes
//
// Panel content (visual + non-visual QObjects) goes in the default slot and is
// appended to contentCol below the section header bar.

import "."
import QtQuick
import Quickshell

FloatingWindow {
    id: root
    title: ""
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false
    onClosed: visible = false

    default property alias content: contentCol.data

    property var sections: []
    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property int rowHeight: 45
    property int headerHeight: 30
    property int colSpacing: 10

    // Panels override with `currentModelLength: function() { ... }`.
    property var currentModelLength: function() { return 0 }

    // When false, the base only forwards via keyPressed(event).
    property bool useDefaultKeys: true
    // When true (default), the base auto-scrolls the Flickable to keep
    // selDevice visible on selection change. Panels with non-standard row
    // geometry (e.g. nested expanded menus) can disable and call
    // root.flick.scrollToVisible(y, h) themselves.
    property bool autoScroll: true

    signal shown()
    signal deviceActivated(int idx)
    signal keyPressed(var event)
    signal sectionChanged(int idx)

    onSelSectionChanged: root.sectionChanged(root.selSection)
    onSelDeviceChanged: if (root.autoScroll && root.inSection) root.flick.scrollToSelection()
    onInSectionChanged: if (root.autoScroll && root.inSection) root.flick.scrollToSelection()

    Shortcut { sequence: "Escape"; onActivated: root.visible = false }

    onVisibleChanged: if (visible) {
        root.selSection = 0
        root.inSection = false
        root.selDevice = 0
        mainRect.forceActiveFocus()
        root.shown()
    }

    property alias flick: flick
    property alias focusTarget: mainRect

    function forceFocus() { mainRect.forceActiveFocus() }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.inSection) root.inSection = false
                else root.selSection = Math.max(0, root.selSection - 1)
            } else if (root.inSection) {
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModelLength() - 1))
            } else {
                root.inSection = true
                root.selDevice = 0
            }
            event.accepted = true; break

        case Qt.Key_Backtab:
            if (root.inSection) root.inSection = false
            event.accepted = true; break

        case Qt.Key_J:
        case Qt.Key_Down:
            if (root.inSection)
                root.selDevice = Math.min(root.selDevice + 1, Math.max(0, root.currentModelLength() - 1))
            else
                root.selSection = Math.min(root.selSection + 1, root.sections.length - 1)
            event.accepted = true; break

        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.inSection)
                root.selDevice = Math.max(root.selDevice - 1, 0)
            else
                root.selSection = Math.max(root.selSection - 1, 0)
            event.accepted = true; break

        case Qt.Key_H:
        case Qt.Key_Left:
        case Qt.Key_L:
        case Qt.Key_Right:
            event.accepted = true; break

        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!root.inSection) { root.inSection = true; root.selDevice = 0 }
            else root.deviceActivated(root.selDevice)
            event.accepted = true; break

        case Qt.Key_Escape:
            if (root.inSection) root.inSection = false
            else root.visible = false
            event.accepted = true; break
        }
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        Keys.onPressed: event => {
            if (root.useDefaultKeys) root.handleKey(event)
            root.keyPressed(event)
        }

        Row {
            anchors.fill: parent
            anchors.margins: root.colSpacing
            spacing: root.colSpacing

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.colSpacing
                    spacing: root.colSpacing

                    Repeater {
                        model: root.sections
                        delegate: Rectangle {
                            width: parent.width
                            height: root.headerHeight
                            color: root.selSection === index ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                            Text {
                                text: modelData.name
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                leftPadding: (root.selSection === index && root.inSection) ? 18 : 0
                            }

                            Text {
                                text: "\u25b6"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                visible: root.selSection === index && root.inSection
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selSection = index
                                    root.inSection = false
                                    mainRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.75
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: root.colSpacing
                    contentHeight: contentCol.height
                    clip: true

                    function scrollToVisible(itemY, itemH) {
                        var viewH = flick.height
                        var maxY = Math.max(0, contentCol.height - viewH)
                        if (itemY < flick.contentY) flick.contentY = Math.max(0, itemY - 40)
                        else if (itemY + itemH > flick.contentY + viewH) flick.contentY = Math.min(maxY, itemY + itemH - viewH + 10)
                    }

                    function scrollToSelection() {
                        var y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
                        flick.scrollToVisible(y, root.rowHeight)
                    }

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: root.colSpacing

                        Rectangle {
                            width: parent.width
                            height: root.headerHeight
                            color: Qt.alpha(Colors.base0d, 0.75)

                            Text {
                                text: root.sections[root.selSection]?.name ?? ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}