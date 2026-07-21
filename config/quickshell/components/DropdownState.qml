// Shared state and keyboard navigation for the per-row action dropdown
// pattern (components/DropdownRow). Each panel whose section rows open
// an action list instantiates this QtObject and supplies two hooks:
//
//   rowActions(idx)      — returns the action list for the row at `idx`
//                         in the current section:
//                           [ { name, action, … }, … ]
//   triggerAction(idx, a) — performs the `a`th action of row `idx`'s
//                         list. This QtObject closes the dropdown
//                         after the call (whether or not the action
//                         succeeded); the hook only does the work.
//
// The panel's onKeyPressed forwards to handleKey(event, selDevice),
// gated on `inSection` and the section predicate. The handler returns
// `true` when it consumed the event (and set event.accepted); the
// caller then early-returns. A `false` return means the panel should
// keep handling — typically PanelNav's default section-row navigation.
//
// Pattern mirrors components/ConfigExpandState.qml (QtObject holding
// shared state + small helpers, instantiated by the caller with hooks
// bound to panel-domain functions).

import QtQuick
import "../util"

QtObject {
    id: root

    // --- State (singleton within a panel) ---
    property int expandedRowIdx: -1
    property int selRowAction: 0

    // --- Caller-supplied hooks ---
    property var rowActions: function(idx) { return [] }
    property var triggerAction: function(idx, actIdx) {}

    // --- Open / close / trigger ---
    function close() {
        root.expandedRowIdx = -1
        root.selRowAction = 0
    }

    function toggle(idx) {
        if (root.expandedRowIdx === idx) root.close()
        else {
            root.expandedRowIdx = idx
            root.selRowAction = 0
        }
    }

    function trigger(idx, actIdx) {
        root.triggerAction(idx, actIdx)
        root.close()
    }

    // --- Keyboard navigation ---
    // Call from the panel's onKeyPressed, gated on inSection + the
    // panel-relevant sections. Returns true if the event was consumed
    // (and event.accepted has been set); false if PanelNav's default
    // section-row nav / climb-out should still run.
    function handleKey(event, selDevice) {
        var open = root.expandedRowIdx === selDevice
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Tab:
            if (event.modifiers & Qt.ShiftModifier) {
                if (open) { root.close(); event.accepted = true; return true }
                return false  // PanelNav climbs out (Shift+Tab to sidebar)
            }
            if (open) root.trigger(selDevice, root.selRowAction)
            else root.toggle(selDevice)
            event.accepted = true
            return true
        case Qt.Key_Backtab:
            if (open) { root.close(); event.accepted = true; return true }
            return false  // PanelNav unwinds the section
        case Qt.Key_Escape:
            if (open) { root.close(); event.accepted = true; return true }
            return false  // PanelNav unwinds the section
        case Qt.Key_J:
        case Qt.Key_Down:
            if (open) {
                root.selRowAction = Scroll.step(
                    root.selRowAction, 1,
                    root.rowActions(selDevice).length)
                event.accepted = true
                return true
            }
            return false  // panel-wide J (EnglishVimKeys) or section-row down
        case Qt.Key_K:
        case Qt.Key_Up:
            if (open) {
                root.selRowAction = Scroll.step(
                    root.selRowAction, -1,
                    root.rowActions(selDevice).length)
                event.accepted = true
                return true
            }
            return false  // PanelNav's section-row up
        }
        return false
    }
}