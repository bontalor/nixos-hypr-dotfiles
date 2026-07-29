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
        return FormatUtil.formattedDate(clock.date) + " " + Qt.formatDateTime(clock.date, fmt)
    }

    SystemClock {
        id: clock
        // Minute precision when seconds are hidden keeps the shell from
        // waking every second just to render an unchanged string.
        precision: PrefStore.timeSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
