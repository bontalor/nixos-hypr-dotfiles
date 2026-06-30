pragma Singleton

import Quickshell
import QtQuick
import "../util"

Singleton {
    id: root

    readonly property string time: {
        Qt.formatDateTime(clock.date, "dddd, MMMM ") + FormatUtil.ordinal(clock.date.getDate()) + Qt.formatDateTime(clock.date, ", yyyy hh:mm:ss AP")
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
