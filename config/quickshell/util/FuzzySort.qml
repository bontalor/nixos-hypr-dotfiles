pragma Singleton

import QtQuick
import Quickshell

// Single fuzzy-score/sort comparator shared by Launcher, EmojiPicker,
// PowerMenu, and any future search list. Replaces three identical copies.

Singleton {
    // Returns the array sorted in place by name-then-fuzzy-rank.
    function sort(query, items) {
        var q = String(query || "").toLowerCase()
        return items.sort(function(a, b) {
            var aName = (a.name || "").toLowerCase()
            var bName = (b.name || "").toLowerCase()
            var aIdx = aName.indexOf(q)
            var bIdx = bName.indexOf(q)
            if (aIdx === 0 && bIdx !== 0) return -1
            if (bIdx === 0 && aIdx !== 0) return 1
            if (aName.length !== bName.length) return aName.length - bName.length
            if (aIdx !== bIdx) return aIdx - bIdx
            if (aName < bName) return -1
            if (aName > bName) return 1
            return 0
        })
    }
}