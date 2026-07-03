import "./util"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    signal unlocked()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    // fprintd fingerprint verification runs concurrently with the password
    // prompt — whichever succeeds first unlocks. The standalone
    // `fprintd-verify` CLI is used (rather than a pam_fprintd stack) because
    // the Quickshell PamContext exchanges text responses, whereas fingerprint
    // verification happens out-of-band on the device.
    //
    // `fingerprintMatched` suppresses a late verify racing a password unlock;
    // `unlockInProgress` ignores the exit of a verify killed by tryUnlock;
    // `fingerprintEnabled` starts from the Settings pref (PrefStore is the
    // shared prefs file, visible to this separate lockscreen instance) and
    // latches false when fprintd is missing or has no usable device/
    // enrolled prints.
    // `fingerprintScanning` is true while fprintd-verify is running (the
    // reader is armed and waiting for a finger).
    // `fingerprintFailed` is true after a transient no-match; the UI tints
    // the fingerprint indicator red. Reset on re-arm or successful match.
    property bool fingerprintEnabled: PrefStore.fingerprintUnlock
    property bool fingerprintMatched: false
    property bool fingerprintScanning: fprintProc.running && root.fingerprintEnabled
    property bool fingerprintFailed: false
    property string fingerprintHint: "or touch fingerprint"

    onCurrentTextChanged: showFailure = false

    function tryUnlock() {
        if (currentText === "") return
        root.unlockInProgress = true
        fprintProc.running = false
        pam.start()
    }

    Component.onCompleted: if (root.fingerprintEnabled) fprintProc.running = true

    Process {
        id: fprintProc
        running: false
        // Wrapped in `sh -c` so a missing fprintd-verify binary yields
        // exit 127 (shell "command not found") rather than a FailedToStart
        // process error — `onExited` then covers every case uniformly.
        command: ["sh", "-c", "fprintd-verify"]
        stdout: StdioCollector { id: fprintOut }

        // fprintd-verify: exit 0 == verify-match, exit 1 == anything else
        // (no-match, no device, no enrolled fingers, daemon down, …).
        // Exit 127 == fprintd not installed. Stdout disambiguates the
        // recoverable exit-1 cases from the permanent ones.
        onExited: (exitCode, exitStatus) => {
            if (root.fingerprintMatched) return
            if (exitCode === 0) {
                root.fingerprintMatched = true
                root.fingerprintFailed = false
                root.unlocked()
                return
            }
            if (root.unlockInProgress) return

            var out = (fprintOut.text || "").toLowerCase()
            // Permanent failures — fprintd missing, no hardware, no prints.
            // Transient failures (session bus down after suspend, daemon
            // restart, no-match) are NOT in this list; the watchdog timer
            // re-arms them.
            var unusable =
                exitCode === 127
                || out.indexOf("no fingers enrolled") >= 0
                || out.indexOf("no default device") >= 0
                || out.indexOf("impossible to verify") >= 0
                || out.indexOf("listenrolledfingers failed") >= 0

            if (unusable) {
                root.fingerprintEnabled = false
                root.fingerprintFailed = false
                root.fingerprintHint = ""
                return
            }

            // Transient no-match / retry-scan / inactivity timeout / session
            // bus hiccup after suspend — re-arm shortly.
            root.fingerprintFailed = true
            root.fingerprintHint = "no match — retry"
            retryTimer.restart()
        }
    }

    // One-shot retry after a transient failure (no-match, timeout).
    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: {
            if (root.fingerprintMatched || root.unlockInProgress
                || !root.fingerprintEnabled) return
            root.fingerprintFailed = false
            root.fingerprintHint = "or touch fingerprint"
            fprintProc.running = true
        }
    }

    // Recurring watchdog: re-arms fprintd-verify if it's not running and
    // fingerprint is still enabled. Handles suspend/resume (where the
    // process may be killed without a clean onExited), fprintd daemon
    // restarts, and any other case where the reader goes idle unexpectedly.
    Timer {
        interval: 5000
        repeat: true
        running: root.fingerprintEnabled && !root.fingerprintMatched
                 && !root.unlockInProgress
        onTriggered: {
            if (!fprintProc.running && root.fingerprintEnabled
                && !root.fingerprintMatched && !root.unlockInProgress) {
                root.fingerprintFailed = false
                root.fingerprintHint = "or touch fingerprint"
                fprintProc.running = true
            }
        }
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText)
            }
        }

        onCompleted: result => {
            root.unlockInProgress = false
            if (result == PamResult.Success) {
                root.unlocked()
            } else {
                root.currentText = ""
                root.showFailure = true
                if (root.fingerprintEnabled && !root.fingerprintMatched) {
                    root.fingerprintFailed = false
                    root.fingerprintHint = "or touch fingerprint"
                    fprintProc.running = true
                }
            }
        }
    }
}
