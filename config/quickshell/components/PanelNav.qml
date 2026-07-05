// Selection / keyboard-navigation state machine for the two-pane Panel
// scaffold. Pure state — no geometry, no scrolling, no windowing: Panel
// binds the inputs, forwards the signals, and reacts to state changes
// for scroll-into-view. Extracted from Panel.qml so the three
// interacting modes live in one focused object.
//
// Modes and invariants:
//   - !inSection: J/K move selSection; Tab/Enter descend into the
//     section (or open the sidebar dropdown for sections with `subs`).
//   - sidebarDropdownOpen: J/K move selSub (content follows live);
//     Tab/Shift+Tab/Escape close; closing deselects (selSub = -1).
//     _lastSub remembers the choice per section for reopening.
//   - inSection: J/K move selDevice within currentModelLength().
//   - inExpandSection (inSection && selSection === expandSection):
//     selConfigItem/selConfigProfile drive the ConfigExpandItem lists;
//     Tab expands onto configCurrentProfile(), Enter activates.
//   - Any section/subsection switch, or leaving the section, collapses
//     the config dropdown (stale-expand guard).
//   - Escape unwinds one level at a time; at the top it emits
//     closeRequested() (Panel hides the window).

import QtQuick
import "../util"

QtObject {
    id: nav

    // --- Inputs, bound by Panel / its subclasses ---
    property var sections: []
    property int expandSection: -1
    property var currentModelLength: function() { return 0 }
    property var configItemCount: function() { return 0 }
    property var configProfileCount: function() { return 0 }
    property var configCurrentProfile: function() { return 0 }

    // --- Selection state ---
    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0
    property int selSub: -1
    property int expandedSection: -1
    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0

    readonly property bool inExpandSection: inSection && selSection === expandSection
    readonly property bool sidebarDropdownOpen: expandedSection === selSection
                                                && sectionSubs(selSection).length > 0

    // Last-chosen subsection per section, so reopening the dropdown
    // lands where the user left off.
    property var _lastSub: ({})

    signal sectionChanged(int idx)
    signal deviceActivated(int idx)
    signal configActivated()
    signal closeRequested()

    onSelSectionChanged: {
        nav.configExpanded = false
        nav.sectionChanged(nav.selSection)
    }
    onSelSubChanged: {
        if (nav.selSub >= 0) nav._lastSub[nav.selSection] = nav.selSub
        nav.configExpanded = false
        nav.selConfigItem = 0
        nav.selConfigProfile = 0
    }
    onInSectionChanged: if (!nav.inSection) nav.configExpanded = false

    function reset() {
        nav.selSection = 0
        nav.selSub = -1
        nav.expandedSection = -1
        nav.inSection = false
        nav.selDevice = 0
        nav.configExpanded = false
        nav.selConfigItem = 0
        nav.selConfigProfile = 0
    }

    function sectionSubs(i) {
        var s = nav.sections[i]
        return (s && s.subs) ? s.subs : []
    }

    function toggleSidebarDropdown() {
        if (nav.expandedSection === nav.selSection) {
            nav.expandedSection = -1
            nav.selSub = -1
        } else {
            nav.expandedSection = nav.selSection
            var last = nav._lastSub[nav.selSection]
            nav.selSub = (last !== undefined && last < nav.sectionSubs(nav.selSection).length) ? last : 0
        }
    }

    // Standard expand/collapse transition for a config item header click
    // (ConfigExpandItem calls this via its `panel` property).
    function toggleConfigItem(idx) {
        if (!nav.inSection) nav.inSection = true
        if (nav.configExpanded && idx === nav.selConfigItem) {
            nav.configExpanded = false
        } else {
            nav.selConfigItem = idx
            nav.configExpanded = true
            nav.selConfigProfile = Math.max(0, nav.configCurrentProfile())
        }
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (nav.inExpandSection && nav.configExpanded) nav.configExpanded = false
                else if (nav.inSection) nav.inSection = false
                else if (nav.sidebarDropdownOpen) nav.toggleSidebarDropdown()
                else nav.selSection = Scroll.clamp(nav.selSection - 1, 0, nav.sections.length - 1)
            } else if (nav.inExpandSection) {
                if (nav.configExpanded) nav.configExpanded = false
                else { nav.configExpanded = true; nav.selConfigProfile = Math.max(0, nav.configCurrentProfile()) }
            } else if (nav.inSection) {
                nav.selDevice = Scroll.step(nav.selDevice, 1, nav.currentModelLength())
            } else if (nav.sectionSubs(nav.selSection).length > 0) {
                nav.toggleSidebarDropdown()
            } else {
                nav.inSection = true
                nav.selDevice = 0
            }
            event.accepted = true; break

        case Qt.Key_Backtab:
            if (nav.inExpandSection && nav.configExpanded) nav.configExpanded = false
            else if (nav.inSection) nav.inSection = false
            else if (nav.sidebarDropdownOpen) nav.toggleSidebarDropdown()
            event.accepted = true; break

        case Qt.Key_J:
        case Qt.Key_Down:
            if (nav.inExpandSection && nav.configExpanded)
                nav.selConfigProfile = Scroll.step(nav.selConfigProfile, 1, nav.configProfileCount())
            else if (nav.inExpandSection)
                nav.selConfigItem = Scroll.step(nav.selConfigItem, 1, nav.configItemCount())
            else if (nav.inSection)
                nav.selDevice = Scroll.step(nav.selDevice, 1, nav.currentModelLength())
            else if (nav.sidebarDropdownOpen)
                nav.selSub = Scroll.step(nav.selSub, 1, nav.sectionSubs(nav.selSection).length)
            else
                nav.selSection = Scroll.clamp(nav.selSection + 1, 0, nav.sections.length - 1)
            event.accepted = true; break

        case Qt.Key_K:
        case Qt.Key_Up:
            if (nav.inExpandSection && nav.configExpanded)
                nav.selConfigProfile = Scroll.step(nav.selConfigProfile, -1, nav.configProfileCount())
            else if (nav.inExpandSection)
                nav.selConfigItem = Scroll.step(nav.selConfigItem, -1, nav.configItemCount())
            else if (nav.inSection)
                nav.selDevice = Scroll.step(nav.selDevice, -1, nav.currentModelLength())
            else if (nav.sidebarDropdownOpen)
                nav.selSub = Scroll.step(nav.selSub, -1, nav.sectionSubs(nav.selSection).length)
            else
                nav.selSection = Scroll.clamp(nav.selSection - 1, 0, nav.sections.length - 1)
            event.accepted = true; break

        case Qt.Key_H:
        case Qt.Key_Left:
        case Qt.Key_L:
        case Qt.Key_Right:
            event.accepted = true; break

        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (nav.inExpandSection) {
                if (nav.configExpanded) nav.configActivated()
                else if (nav.configItemCount() > 0) { nav.configExpanded = true; nav.selConfigProfile = Math.max(0, nav.configCurrentProfile()) }
            } else if (!nav.inSection) {
                if (nav.sectionSubs(nav.selSection).length > 0 && !nav.sidebarDropdownOpen) {
                    nav.toggleSidebarDropdown()
                } else if (nav.sectionSubs(nav.selSection).length === 0 || nav.selSub >= 0) {
                    nav.inSection = true
                    nav.selDevice = 0
                }
            } else {
                nav.deviceActivated(nav.selDevice)
            }
            event.accepted = true; break

        case Qt.Key_Escape:
            if (nav.selSection === nav.expandSection && nav.configExpanded) nav.configExpanded = false
            else if (nav.inSection) nav.inSection = false
            else if (nav.sidebarDropdownOpen) nav.toggleSidebarDropdown()
            else nav.closeRequested()
            event.accepted = true; break
        }
    }
}
