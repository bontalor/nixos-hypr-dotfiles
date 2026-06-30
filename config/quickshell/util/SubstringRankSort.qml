pragma Singleton

import QtQuick
import Quickshell

// Substring-rank sort comparator shared by Launcher, EmojiPicker,
// PowerMenu, and any future search list. Replaces three identical copies
// that previously lived inline in each search panel.
//
// Named "SubstringRankSort" (not "FuzzySort") because the comparator
// uses plain indexOf substring matching, not subsequence fuzzy matching
// — the name reflects the actual behavior.

Singleton {
    // Returns a new array sorted by substring rank. The original `items`
    // is left untouched (a shallow copy is sorted and returned).
    //
    // Rank precedence:
    //   1. prefix match (indexOf === 0) beats non-prefix
    //   2. shorter name beats longer
    //   3. earlier substring index beats later
    //   4. lexicographic tie-break
    //
    // keyFn(item) -> string  lets callers match against a field other
    // than `.name` (e.g. a synthesized "name|genericName|comment" key).
    // Defaults to `item.name`.
    function sort(query, items, keyFn) {
        var q = String(query || "").toLowerCase()
        var copy = items.slice(0)
        var key = keyFn || function(item) { return (item && item.name) || "" }
        copy.sort(function(a, b) {
            var aName = String(key(a) || "").toLowerCase()
            var bName = String(key(b) || "").toLowerCase()
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
        return copy
    }
}
