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
import "../util"
import QtQuick
import Quickshell

FloatingWindow {
    id: root
    title: ""
    color: "transparent"
    implicitWidth: Theme.panelWidth
    implicitHeight: Theme.panelHeight
    visible: false
    onClosed: visible = false

    default property alias content: contentCol.data

    property var sections: []
    property string sidebarHeader: ""
    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property int rowHeight: Theme.rowHeight
    property int headerHeight: Theme.headerHeight
    property int colSpacing: Theme.colSpacing

    // Panels override with `currentModelLength: function() { ... }`.
    property var currentModelLength: function() { return 0 }

    // When false, the base only forwards via keyPressed(event).
    property bool useDefaultKeys: true
    // When true (default), the base auto-scrolls the Flickable to keep
    // selDevice visible on selection change. Panels with non-standard row
    // geometry (e.g. nested expanded menus) can disable and call
    // Scroll.scrollIntoView(flick, y, h) themselves.
    property bool autoScroll: true

    signal shown()
    signal deviceActivated(int idx)
    signal keyPressed(var event)
    signal sectionChanged(int idx)

    onSelSectionChanged: root.sectionChanged(root.selSection)
    onSelDeviceChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onInSectionChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()

    // Single Escape handler: exits inSection first, then closes the panel.
    // (Previously a Shortcut at top level closed the panel outright,
    // bypassing the inSection-aware Escape logic in handleKey below.)
    Shortcut {
        sequence: "Escape"
        onActivated: root.handleKey({ key: Qt.Key_Escape, accepted: false, modifiers: 0 })
    }

    onVisibleChanged: if (visible) {
        root.selSection = 0
        root.inSection = false
        root.selDevice = 0
        mainRect.forceActiveFocus()
        root.shown()
    }

    function forceFocus() { mainRect.forceActiveFocus() }

    // Scroll the content Flickable so the currently-selected row is
    // visible. Delegates the clamp arithmetic to Scroll.scrollIntoView
    // (shared with SearchPanel and VolumePanel).
    function scrollToSelection() {
        var y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
        Scroll.scrollIntoView(flick, y, root.rowHeight)
    }

    // Public scroll helper for subclasses with non-standard row geometry
    // (e.g. nested expanded menus). Delegates to the shared Scroll util
    // so the clamp arithmetic isn't reimplemented per panel.
    function scrollToVisible(itemY, itemH) {
        Scroll.scrollIntoView(flick, itemY, itemH)
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (root.inSection) root.inSection = false
                else root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
            } else if (root.inSection) {
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
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
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
            else
                root.selSection = Scroll.clamp(root.selSection + 1, 0, root.sections.length - 1)
            event.accepted = true; break

        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.inSection)
                root.selDevice = Scroll.step(root.selDevice, -1, root.currentModelLength())
            else
                root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
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
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: root.colSpacing
                    spacing: root.colSpacing

                    // Optional sidebar header (e.g. "Sources" in MediaPanel).
                    Rectangle {
                        width: parent.width
                        height: root.headerHeight
                        visible: root.sidebarHeader !== ""
                        color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                        ThemeText {
                            text: root.sidebarHeader
                            anchors {
                                left: parent.left; leftMargin: Theme.margin
                                verticalCenter: parent.verticalCenter
                            }
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: root.sections
                        delegate: Rectangle {
                            width: parent.width
                            height: root.headerHeight
                            color: root.selSection === index || sectionMouse.containsMouse ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

                            ThemeText {
                                text: modelData.name
                                anchors {
                                    left: parent.left; leftMargin: Theme.margin
                                    right: parent.right; rightMargin: Theme.margin
                                    verticalCenter: parent.verticalCenter
                                }
                                elide: Text.ElideRight
                                leftPadding: (root.selSection === index && root.inSection) ? Theme.iconSize - Theme.margin : 0
                            }

                            ThemeText {
                                text: Icon.chevronRight
                                anchors {
                                    left: parent.left; leftMargin: Theme.margin
                                    verticalCenter: parent.verticalCenter
                                }
                                visible: root.selSection === index && root.inSection
                            }

                            MouseArea {
                                id: sectionMouse
                                anchors.fill: parent
                                hoverEnabled: true
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
                color: Qt.alpha(Colors.base00, Theme.alphaBackground)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: root.colSpacing
                    contentHeight: contentCol.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: root.colSpacing

                        Rectangle {
                            width: parent.width
                            height: root.headerHeight
                            color: Qt.alpha(Colors.base0d, Theme.alphaSectionHeader)

                            ThemeText {
                                text: root.sections[root.selSection]?.name ?? ""
                                anchors {
                                    left: parent.left; leftMargin: Theme.margin
                                    verticalCenter: parent.verticalCenter
                                }
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
