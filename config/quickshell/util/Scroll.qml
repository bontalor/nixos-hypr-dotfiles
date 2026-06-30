pragma Singleton

import QtQuick
import Quickshell

// Flickable / list-navigation helpers. Replaces three near-identical
// scroll-into-view reimplementations in Panel.qml, SearchPanel.qml, and
// VolumePanel.qml, plus four copies of the same Math.min/Math.max
// selection-clamp expression.

Singleton {
    // Clamp v into [lo, hi]. Used by every keyboard-nav handler to keep
    // the selection index inside the model length.
    function clamp(v, lo, hi) {
        return Math.min(Math.max(v, lo), hi)
    }

    // Selection step in either direction, clamped to [0, length-1].
    // step(2, 1, 5) -> 3 ; step(0, -1, 5) -> 0
    function step(index, delta, length) {
        if (length <= 0) return 0
        return clamp(index + delta, 0, length - 1)
    }

    // Scroll a Flickable so that the row at itemY (in content coordinates)
    // of height itemH is fully visible. Mirrors the clamp logic that was
    // triplicated across Panel/SearchPanel/VolumePanel.
    function scrollIntoView(flickable, itemY, itemH) {
        if (!flickable) return
        var viewH = flickable.height
        var maxY = Math.max(0, flickable.contentHeight - viewH)
        if (itemY < flickable.contentY) {
            flickable.contentY = Math.max(0, itemY)
        } else if (itemY + itemH > flickable.contentY + viewH) {
            flickable.contentY = Math.min(maxY, itemY + itemH - viewH)
        }
    }
}
