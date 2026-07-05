pragma Singleton

import Quickshell
import QtQuick
import "../util"

Singleton {
    id: root

    readonly property string time: {
        var fmt = PrefStore.timeFormat === "24h"
            ? (PrefStore.timeSeconds ? "HH:mm:ss" : "HH:mm")
            : (PrefStore.timeSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        return Qt.formatDateTime(clock.date, "dddd, MMMM ") + FormatUtil.ordinal(clock.date.getDate())
            + Qt.formatDateTime(clock.date, ", yyyy ")
            + Qt.formatDateTime(clock.date, fmt)
    }

    SystemClock {
        id: clock
        // Minute precision when seconds are hidden keeps the shell from
        // waking every second just to render an unchanged string.
        precision: PrefStore.timeSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
