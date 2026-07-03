// Shared scaffold for two-pane (sections list + content) panels.
//
// Provides the standard FloatingWindow + sidebar + content Flickable + section
// header bar, plus J/K/Tab keyboard navigation in the common
// "list of selectable rows per section" pattern.
//
// Sections may carry subsections: a `subs: [{name}, ...]` entry renders
// the section as a sidebar dropdown with the same behavior as the
// config dropdowns (ConfigExpandItem): J/K move the section highlight,
// Tab/Shift+Tab (or a header click) open/close the dropdown, J/K then
// move through the subsections — selSub tracks the choice and drives
// the content. Closing the dropdown deselects. Sections without `subs`
// behave exactly as before.
//
// Panels override behavior via property bindings:
//   - currentModelLength: function() -> int   (rows in the current section)
// And via signals:
//   - shown()            emitted when the panel becomes visible (after reset)
//   - deviceActivated(i) emitted on Enter when a row is selected
//   - keyPressed(event)  every keypress, BEFORE the default handler — set
//                        event.accepted to pre-empt it (or useDefaultKeys:false
//                        to fully take over)
//   - sectionChanged(i)  emitted when selSection changes
//
// Expandable-config sections (opt-in): set `expandSection` to the section
// index whose rows expand into an inline profile sub-list (the
// ConfigExpandItem pattern shared by VolumePanel and WeatherPanel). The
// default key handler then drives configExpanded/selConfigItem/
// selConfigProfile, and `configActivated()` fires on Enter over a profile.
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

    // Panels registry key (Panels.network, Panels.volume, …). When set,
    // the panel registers itself on creation — shell.qml just declares
    // `NetworkPanel { panelKey: Panels.network }` with no separate
    // registration list to keep in sync.
    property string panelKey: ""
    Component.onCompleted: if (panelKey !== "") Panels.register(panelKey, this)

    property var sections: []
    property string sidebarHeader: ""
    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    // Subsection state: selSub is the chosen subsection within
    // selSection (-1 when the section has none); expandedSection is the
    // section whose sidebar dropdown is open (-1 when none).
    property int selSub: -1
    property int expandedSection: -1

    property int rowHeight: Theme.rowHeight
    property int headerHeight: Theme.headerHeight
    property int colSpacing: Theme.colSpacing

    // Panels override with `currentModelLength: function() { ... }`.
    property var currentModelLength: function() { return 0 }

    // --- Expandable-config section support (opt-in via expandSection) ---
    property int expandSection: -1
    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0
    // Panels override these with the item count of the expandable section
    // and the profile count of the currently-selected item.
    property var configItemCount: function() { return 0 }
    property var configProfileCount: function() { return 0 }
    // Profile index the dropdown should open on — panels override to
    // return the currently-active option (e.g. the device's active
    // profile) so expanding lands there instead of on the first row.
    property var configCurrentProfile: function() { return 0 }

    // Selection is inside the expandable section's item list.
    readonly property bool inExpandSection: inSection && selSection === expandSection

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
    signal configActivated()

    // Switching sections or leaving one collapses any open config
    // dropdown. Without this, configExpanded stayed stale-true after a
    // sidebar click — masked in panels whose isExpanded binding included
    // inSection (VolumePanel), visible in those that didn't (WeatherPanel).
    onSelSectionChanged: {
        root.configExpanded = false
        root.sectionChanged(root.selSection)
    }
    // Switching subsections resets the config-expand state like a
    // section switch does — the content list changed underneath it.
    onSelSubChanged: {
        if (root.selSub >= 0) root._lastSub[root.selSection] = root.selSub
        root.configExpanded = false
        root.selConfigItem = 0
        root.selConfigProfile = 0
    }
    onSelDeviceChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onInSectionChanged: {
        if (!root.inSection) root.configExpanded = false
        if (root.autoScroll && root.inSection) root.scrollToSelection()
    }
    onSelConfigItemChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onSelConfigProfileChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onConfigExpandedChanged: if (root.autoScroll && root.inSection && root.configExpanded) root.scrollToSelection()

    // Single Escape handler: exits inSection first, then closes the panel.
    // (Previously a Shortcut at top level closed the panel outright,
    // bypassing the inSection-aware Escape logic in handleKey below.)
    // Mirrors mainRect's dispatch order: keyPressed can pre-empt.
    Shortcut {
        sequence: "Escape"
        onActivated: {
            var ev = { key: Qt.Key_Escape, accepted: false, modifiers: 0 }
            root.keyPressed(ev)
            if (!ev.accepted) root.handleKey(ev)
        }
    }

    onVisibleChanged: if (visible) {
        root.selSection = 0
        root.selSub = -1
        root.expandedSection = -1
        root.inSection = false
        root.selDevice = 0
        root.configExpanded = false
        root.selConfigItem = 0
        root.selConfigProfile = 0
        mainRect.forceActiveFocus()
        root.shown()
    }

    property alias flick: flick

    function forceFocus() { mainRect.forceActiveFocus() }

    // Scroll the content Flickable so the currently-selected row is
    // visible. Handles both the standard fixed-stride rows and the
    // expandable-config geometry (item rows with an inline profile
    // sub-list of searchRowHeight rows below the selected item).
    function scrollToSelection() {
        var y, h
        if (root.selSection === root.expandSection) {
            y = root.headerHeight + root.colSpacing + root.selConfigItem * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
            if (root.configExpanded) {
                y += root.rowHeight + root.selConfigProfile * Theme.searchRowHeight
                h = Theme.searchRowHeight
            }
        } else {
            y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        Scroll.scrollIntoView(flick, y, h)
    }

    // Sidebar dropdown state for the selected section (sections with
    // `subs`). Tab/Shift+Tab toggle it like every other dropdown; J/K
    // move through the subsections while it's open, and the content
    // follows selSub live. Closing deselects (blank content area).
    function sectionSubs(i) {
        var s = root.sections[i]
        return (s && s.subs) ? s.subs : []
    }

    readonly property bool sidebarDropdownOpen: root.expandedSection === root.selSection
                                                && sectionSubs(root.selSection).length > 0

    // Last-chosen subsection per section, so reopening the dropdown
    // lands where the user left off (there is no "current value" for
    // subsections). Tracked in onSelSubChanged.
    property var _lastSub: ({})

    function toggleSidebarDropdown() {
        if (root.expandedSection === root.selSection) {
            root.expandedSection = -1
            root.selSub = -1
        } else {
            root.expandedSection = root.selSection
            var last = root._lastSub[root.selSection]
            root.selSub = (last !== undefined && last < root.sectionSubs(root.selSection).length) ? last : 0
        }
    }

    // Standard expand/collapse transition for a config item header click.
    // ConfigExpandItem calls this via its `panel` property — previously
    // the same body was hand-rolled in every onToggled handler.
    function toggleConfigItem(idx) {
        if (!root.inSection) root.inSection = true
        if (root.configExpanded && idx === root.selConfigItem) {
            root.configExpanded = false
        } else {
            root.selConfigItem = idx
            root.configExpanded = true
            root.selConfigProfile = Math.max(0, root.configCurrentProfile())
        }
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
                if (root.inExpandSection && root.configExpanded) root.configExpanded = false
                else if (root.inSection) root.inSection = false
                else if (root.sidebarDropdownOpen) root.toggleSidebarDropdown()
                else root.selSection = Scroll.clamp(root.selSection - 1, 0, root.sections.length - 1)
            } else if (root.inExpandSection) {
                if (root.configExpanded) root.configExpanded = false
                else { root.configExpanded = true; root.selConfigProfile = Math.max(0, root.configCurrentProfile()) }
            } else if (root.inSection) {
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
            } else if (root.sectionSubs(root.selSection).length > 0) {
                root.toggleSidebarDropdown()
            } else {
                root.inSection = true
                root.selDevice = 0
            }
            event.accepted = true; break

        case Qt.Key_Backtab:
            if (root.inExpandSection && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            else if (root.sidebarDropdownOpen) root.toggleSidebarDropdown()
            event.accepted = true; break

        case Qt.Key_J:
        case Qt.Key_Down:
            if (root.inExpandSection && root.configExpanded)
                root.selConfigProfile = Scroll.step(root.selConfigProfile, 1, root.configProfileCount())
            else if (root.inExpandSection)
                root.selConfigItem = Scroll.step(root.selConfigItem, 1, root.configItemCount())
            else if (root.inSection)
                root.selDevice = Scroll.step(root.selDevice, 1, root.currentModelLength())
            else if (root.sidebarDropdownOpen)
                root.selSub = Scroll.step(root.selSub, 1, root.sectionSubs(root.selSection).length)
            else
                root.selSection = Scroll.clamp(root.selSection + 1, 0, root.sections.length - 1)
            event.accepted = true; break

        case Qt.Key_K:
        case Qt.Key_Up:
            if (root.inExpandSection && root.configExpanded)
                root.selConfigProfile = Scroll.step(root.selConfigProfile, -1, root.configProfileCount())
            else if (root.inExpandSection)
                root.selConfigItem = Scroll.step(root.selConfigItem, -1, root.configItemCount())
            else if (root.inSection)
                root.selDevice = Scroll.step(root.selDevice, -1, root.currentModelLength())
            else if (root.sidebarDropdownOpen)
                root.selSub = Scroll.step(root.selSub, -1, root.sectionSubs(root.selSection).length)
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
            if (root.inExpandSection) {
                if (root.configExpanded) root.configActivated()
                else if (root.configItemCount() > 0) { root.configExpanded = true; root.selConfigProfile = Math.max(0, root.configCurrentProfile()) }
            } else if (!root.inSection) {
                if (root.sectionSubs(root.selSection).length > 0 && !root.sidebarDropdownOpen) {
                    root.toggleSidebarDropdown()
                } else if (root.sectionSubs(root.selSection).length === 0 || root.selSub >= 0) {
                    root.inSection = true
                    root.selDevice = 0
                }
            } else {
                root.deviceActivated(root.selDevice)
            }
            event.accepted = true; break

        case Qt.Key_Escape:
            if (root.selSection === root.expandSection && root.configExpanded) root.configExpanded = false
            else if (root.inSection) root.inSection = false
            else if (root.sidebarDropdownOpen) root.toggleSidebarDropdown()
            else root.visible = false
            event.accepted = true; break
        }
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        // keyPressed first so panels can pre-empt individual keys (by
        // setting event.accepted) without taking over the whole handler.
        Keys.onPressed: event => {
            root.keyPressed(event)
            if (root.useDefaultKeys && !event.accepted) root.handleKey(event)
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
                        delegate: Column {
                            id: sectionCol
                            width: parent.width
                            property int sectionIndex: index
                            property var subs: modelData.subs ?? []
                            property bool hasSubs: subs.length > 0
                            property bool expanded: root.expandedSection === index

                            // Subless section: plain selectable row.
                            Rectangle {
                                visible: !sectionCol.hasSubs
                                width: parent.width
                                height: root.headerHeight
                                color: root.selSection === sectionCol.sectionIndex || sectionMouse.containsMouse
                                       ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

                                ThemeText {
                                    text: modelData.name
                                    anchors {
                                        left: parent.left; leftMargin: Theme.margin
                                        right: parent.right; rightMargin: Theme.margin
                                        verticalCenter: parent.verticalCenter
                                    }
                                    elide: Text.ElideRight
                                    leftPadding: (root.selSection === sectionCol.sectionIndex && root.inSection)
                                                 ? Theme.iconSize - Theme.margin : 0
                                }

                                ThemeText {
                                    text: Icon.chevronRight
                                    anchors {
                                        left: parent.left; leftMargin: Theme.margin
                                        verticalCenter: parent.verticalCenter
                                    }
                                    visible: root.selSection === sectionCol.sectionIndex && root.inSection
                                }

                                MouseArea {
                                    id: sectionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selSection = sectionCol.sectionIndex
                                        root.selSub = -1
                                        root.inSection = false
                                        mainRect.forceActiveFocus()
                                    }
                                }
                            }

                            // Section with subsections: the same expand/
                            // collapse scaffold as the config dropdowns
                            // (VolumePanel profiles, WeatherPanel city).
                            // Highlighted while it is the selected
                            // section, like any other section row.
                            ConfigExpandItem {
                                visible: sectionCol.hasSubs
                                label: modelData.name
                                isSelected: root.selSection === sectionCol.sectionIndex
                                isExpanded: sectionCol.expanded
                                profileCount: sectionCol.subs.length
                                onToggled: {
                                    root.selSection = sectionCol.sectionIndex
                                    root.toggleSidebarDropdown()
                                    mainRect.forceActiveFocus()
                                }

                                Repeater {
                                    model: sectionCol.subs
                                    delegate: ConfigProfileRow {
                                        label: modelData.name
                                        isSelected: root.selSection === sectionCol.sectionIndex && root.selSub === index
                                        marker: isSelected && root.inSection
                                        onClicked: {
                                            root.selSection = sectionCol.sectionIndex
                                            root.selSub = index
                                            root.inSection = false
                                            mainRect.forceActiveFocus()
                                        }
                                    }
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
                                // Subsection name when one is selected,
                                // else the section name.
                                text: root.sections[root.selSection]?.subs?.[root.selSub]?.name
                                      ?? root.sections[root.selSection]?.name ?? ""
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
