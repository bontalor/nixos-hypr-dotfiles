// Time.qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  // EVIL ORDINAL FUNCTION FROM HELL
  function ordinal(n) {
    const s = ["th","st","nd","rd"]
    const v = n % 100
    return n + (s[(v-20)%10] || s[v] || s[0])
  }

  readonly property string time: {
    Qt.formatDateTime(clock.date, "dddd, MMMM ") + ordinal(clock.date.getDate()) + Qt.formatDateTime(clock.date, ", yyyy hh:mm:ss AP")
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }
}
