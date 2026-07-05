// Windowed dev harness for the lockscreen — renders LockSurface in a
// plain FloatingWindow instead of a WlSessionLock, so it can be
// iterated on without actually locking the session:
//
//   qs -p lockscreen/test.qml
//
// Escape/unlock just quits. Not part of the running shell.

import "."
import QtQuick
import Quickshell

ShellRoot {
    LockContext {
        id: lockContext
        onUnlocked: Qt.quit()
    }

    FloatingWindow {
        implicitWidth: 800
        implicitHeight: 600
        color: "transparent"

        LockSurface {
            anchors.fill: parent
            context: lockContext
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }
}
