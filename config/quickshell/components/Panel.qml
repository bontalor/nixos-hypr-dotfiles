// Shared scaffold for two-pane (sections list + content) panels.
//
// Provides the standard FloatingWindow + sidebar + content Flickable +
// section header bar. All selection/keyboard-navigation state lives in
// PanelNav (components/PanelNav.qml — see its header for the mode
// invariants); the aliases below keep the subclass API identical, and
// this file owns everything visual: geometry, scroll-into-view, focus,
// and the sidebar/content composition.
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
// ConfigExpandItem pattern shared by VolumePanel and NetworkPanel), and
// override configItemCount/configProfileCount/configCurrentProfile;
// `configActivated()` fires on Enter over a profile.
//
// Panel content (visual + non-visual QObjects) goes in the default slot and is
// appended to contentCol below the section header bar.

pragma ComponentBehavior: Bound

import "."
import "../theme"
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

    // --- Navigation state (see components/PanelNav.qml) ---
    property alias sections: nav.sections
    property alias selSection: nav.selSection
    property alias inSection: nav.inSection
    property alias selDevice: nav.selDevice
    property alias selSub: nav.selSub
    property alias expandedSection: nav.expandedSection
    property alias expandSection: nav.expandSection
    property alias configExpanded: nav.configExpanded
    property alias selConfigItem: nav.selConfigItem
    property alias selConfigProfile: nav.selConfigProfile
    property alias currentModelLength: nav.currentModelLength
    property alias configItemCount: nav.configItemCount
    property alias configProfileCount: nav.configProfileCount
    property alias configCurrentProfile: nav.configCurrentProfile
    property alias inExpandSection: nav.inExpandSection
    property alias sidebarDropdownOpen: nav.sidebarDropdownOpen

    property string sidebarHeader: ""
    property int rowHeight: Theme.rowHeight
    property int headerHeight: Theme.headerHeight
    property int colSpacing: Theme.colSpacing

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

    PanelNav {
        id: nav
        onSectionChanged: idx => root.sectionChanged(idx)
        onDeviceActivated: idx => root.deviceActivated(idx)
        onConfigActivated: root.configActivated()
        onCloseRequested: root.visible = false
    }

    // Scroll-into-view reactions to the nav state (visual concern, so it
    // stays here rather than in PanelNav).
    onSelDeviceChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onInSectionChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onSelConfigItemChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onSelConfigProfileChanged: if (root.autoScroll && root.inSection) root.scrollToSelection()
    onConfigExpandedChanged: if (root.autoScroll && root.inSection && root.configExpanded) root.scrollToSelection()

    // Single Escape handler: exits inSection first, then closes the panel.
    // Mirrors mainRect's dispatch order: keyPressed can pre-empt.
    Shortcut {
        sequence: "Escape"
        onActivated: {
            var ev = { key: Qt.Key_Escape, accepted: false, modifiers: 0 }
            root.keyPressed(ev)
            if (!ev.accepted) nav.handleKey(ev)
        }
    }

    onVisibleChanged: if (visible) {
        nav.reset()
        mainRect.forceActiveFocus()
        root.shown()
    }

    property alias flick: flick

    function forceFocus() { mainRect.forceActiveFocus() }

    // Kept as forwarders so subclasses and ConfigExpandItem keep their
    // existing entry points (panel.toggleConfigItem, root.sectionSubs, …).
    function handleKey(event) { nav.handleKey(event) }
    function sectionSubs(i) { return nav.sectionSubs(i) }
    function toggleSidebarDropdown() { nav.toggleSidebarDropdown() }
    function toggleConfigItem(idx) { nav.toggleConfigItem(idx) }

    // Standard per-delegate "select this row" stomp used by every panel
    // with a DropdownState — sets inSection + selDevice so the row
    // becomes the keyboard highlight and PanelNav's section-row nav
    // takes over from here. Panels bind `dropdown.selectRow: root.selectRow`
    // once per DropdownState instance, then every dropdown delegate
    // just calls root.toggleRowDropdown(idx) / root.triggerRowAction(idx, a),
    // skipping the inline `inSection=true; selDevice=idx` block that
    // used to appear ~16 times across Network/Volume/Ffmpeg/Battery.
    function selectRow(idx) {
        nav.inSection = true
        nav.selDevice = idx
    }

    // Scroll the content Flickable so the currently-selected row is
    // visible. Handles both the standard fixed-stride rows and the
    // expandable-config geometry (item rows with an inline profile
    // sub-list of searchRowHeight rows below the selected item). The
    // config-section math is shared via Scroll.expandConfigTarget so
    // VolumePanel's override (which needs the same computation) calls
    // the same helper instead of carrying a verbatim copy.
    function scrollToSelection() {
        var y, h
        if (root.selSection === root.expandSection && root.expandSection !== -1) {
            var t = Scroll.expandConfigTarget(
                root.headerHeight, root.colSpacing,
                root.rowHeight, Theme.searchRowHeight,
                root.selConfigItem, root.configExpanded,
                root.selConfigProfile)
            y = t.y; h = t.h
        } else {
            y = root.headerHeight + root.colSpacing + root.selDevice * (root.rowHeight + root.colSpacing)
            h = root.rowHeight
        }
        Scroll.scrollIntoView(flick, y, h)
    }

    // Public scroll helper for subclasses with non-standard row geometry
    // (e.g. nested expanded menus). Delegates to the shared Scroll util
    // so the clamp arithmetic isn't reimplemented per panel.
    function scrollToVisible(itemY, itemH) {
        Scroll.scrollIntoView(flick, itemY, itemH)
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
            if (root.useDefaultKeys && !event.accepted) nav.handleKey(event)
        }

        Row {
            anchors.fill: parent
            anchors.margins: root.colSpacing
            spacing: root.colSpacing

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.surface, Theme.alphaBackground)
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
                        color: Qt.alpha(Colors.accent, Theme.alphaSectionHeader)

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
                            required property var modelData
                            required property int index
                            width: parent.width
                            property int sectionIndex: index
                            property var subs: sectionCol.modelData.subs ?? []
                            property bool hasSubs: subs.length > 0
                            property bool expanded: root.expandedSection === index

                            // Subless section: plain selectable row.
                            Rectangle {
                                visible: !sectionCol.hasSubs
                                width: parent.width
                                height: root.headerHeight
                                color: root.selSection === sectionCol.sectionIndex || sectionMouse.containsMouse
                                       ? Qt.alpha(Colors.selected, Theme.alphaSelected) : "transparent"

                                ThemeText {
                                    text: sectionCol.modelData.name
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
                            // (VolumePanel profiles, SettingsPanel groups).
                            // Highlighted while it is the selected
                            // section, like any other section row.
                            ConfigExpandItem {
                                visible: sectionCol.hasSubs
                                label: sectionCol.modelData.name
                                isSelected: root.selSection === sectionCol.sectionIndex
                                isExpanded: sectionCol.expanded
                                profileCount: sectionCol.subs.length
                                onToggled: {
                                    root.selSection = sectionCol.sectionIndex
                                    nav.toggleSidebarDropdown()
                                    mainRect.forceActiveFocus()
                                }

                                Repeater {
                                    model: sectionCol.subs
                                    delegate: ConfigProfileRow {
                                        id: profileRow
                                        required property var modelData
                                        required property int index
                                        label: profileRow.modelData.name
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
                color: Qt.alpha(Colors.surface, Theme.alphaBackground)

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
                            color: Qt.alpha(Colors.accent, Theme.alphaSectionHeader)

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
