// Two-rectangle drop shadow drawn `Theme.margin` px to the right and
// below its parent. Replaces the ~14-line shadow block duplicated across
// OsdPopup, NotifPopup, Bar, and LockSurface — each of which hard-coded
// the same `+10/-10` magic and raw "#000000".
//
// DropShadow fills its parent. The parent should be sized to include
// the shadow extent (e.g. width: contentWidth + Theme.margin).
// The shadow is drawn at 0.75 alpha (Theme.alphaBackground) to match
// the original hand-rolled shadows.

import "."
import QtQuick

Item {
    id: root

    // Shadow tint at Theme.alphaBackground (0.75) — matches the original
    // Qt.alpha("#000000", Theme.alphaBackground) used everywhere.
    property color shadowColor: Qt.alpha("#000000", Theme.alphaBackground)
    // Shadow extent on each axis. Defaults to Theme.margin.
    property int extent: Theme.margin

    // Bottom shadow strip — starts at x=extent (aligned with the right
    // shadow), runs to the bottom-right corner.
    Rectangle {
        color: root.shadowColor
        x: root.extent
        y: parent.height - root.extent
        width: parent.width - root.extent
        height: root.extent
    }

    // Right shadow strip — starts at y=extent (below the top-left
    // corner), ends where the bottom strip begins (no overlap).
    Rectangle {
        color: root.shadowColor
        x: parent.width - root.extent
        y: root.extent
        width: root.extent
        height: parent.height - 2 * root.extent
    }
}
