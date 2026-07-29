pragma Singleton

import Quickshell
import QtQuick
import "../util"

Singleton {
    id: root

    readonly property var now: clock.date

    readonly property string time: {
        root._refresh   // bump on pref change to force re-evaluation
        var now = root.now
        var fmt = PrefStore.timeFormat === "24h"
            ? (PrefStore.timeSeconds ? "HH:mm:ss" : "HH:mm")
            : (PrefStore.timeSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        return FormatUtil.formattedDate(now) + " " + Qt.formatDateTime(now, fmt)
    }

    // Sentinel bumped on seconds/format change so the `time` binding
    // re-evaluates immediately rather than waiting up to 60s for the
    // next SystemClock tick after toggling `timeSeconds`.
    property int _refresh: 0
    Connections {
        target: PrefStore
        function onTimeSecondsChanged() { root._refresh++ }
        function onTimeFormatChanged() { root._refresh++ }
    }

    SystemClock {
        id: clock
        precision: PrefStore.timeSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
