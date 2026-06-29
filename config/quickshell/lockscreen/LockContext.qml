import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    property bool fpAvailable: false
    property bool fpActive: false
    property string fpMessage: ""

    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "") return
        root.showFailure = false
        passwd.start()
    }

    function startFprint() {
        if (!root.fpAvailable || root.unlockInProgress) return
        root.fpActive = true
        root.fpMessage = ""
        fprint.start()
    }

    Process {
        id: availProc
        running: false
        command: ["sh", "-c",
            "fprintd-list 2>/dev/null | grep -qi finger && echo AVAILABLE || echo UNAVAILABLE"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.fpAvailable = text.trim() === "AVAILABLE"
                if (root.fpAvailable)
                    fpStartTimer.start()
            }
        }
    }

    Timer {
        id: fpStartTimer
        interval: 800
        onTriggered: root.startFprint()
    }

    Timer {
        id: fpRestartTimer
        interval: 1500
        onTriggered: root.startFprint()
    }

    Component.onCompleted: availProc.running = true

    PamContext {
        id: passwd
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText)
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
                if (!root.unlockInProgress) {
                    root.unlockInProgress = true
                    fprint.abort()
                    root.unlocked()
                }
            } else {
                root.currentText = ""
                root.showFailure = true
            }
            root.unlockInProgress = false
        }
    }

    PamContext {
        id: fprint
        configDirectory: "pam"
        config: "fprint.conf"

        onPamMessage: {
            root.fpMessage = message
            if (this.responseRequired)
                this.respond("")
        }

        onCompleted: result => {
            root.fpActive = false
            if (result == PamResult.Success) {
                if (!root.unlockInProgress) {
                    root.unlockInProgress = true
                    passwd.abort()
                    root.unlocked()
                }
            } else if (root.fpAvailable && !root.unlockInProgress && !passwd.active) {
                fpRestartTimer.start()
            }
        }
    }
}
