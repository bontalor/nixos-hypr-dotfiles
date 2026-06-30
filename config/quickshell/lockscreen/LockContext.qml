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
    // `fingerprintEnabled` latches false when fprintd is missing or has no
    // usable device/enrolled prints.
    //
    // `fingerprintScanning` is true briefly after fprintd-verify exits (a
    // scan just completed) — fprintd-verify blocks silently while waiting for
    // a finger, so `Process.running` can't distinguish "idle" from "finger on
    // scanner." The brief `fingerprintScanning` window gives the user visual
    // feedback that their fingerprint was read, before the result (unlock or
    // retry) is processed.
    //
    // `fingerprintFailed` is true after a transient no-match; the UI tints
    // the fingerprint indicator red. Reset on re-arm or successful match.
    property bool fingerprintEnabled: true
    property bool fingerprintMatched: false
    property bool fingerprintScanning: false
    property bool fingerprintFailed: false
    property string fingerprintHint: "or touch fingerprint"

    // Stashed exit code while scanFeedbackTimer runs.
    property int _pendingExitCode: -1

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
        command: ["sh", "-c", "fprintd-verify"]
        stdout: StdioCollector { id: fprintOut }

        onExited: (exitCode, exitStatus) => {
            if (root.fingerprintMatched) return
            if (root.unlockInProgress) return

            // A scan just completed. Show "scanning fingerprint..." briefly
            // before processing the result, so the user sees feedback that
            // their finger was read.
            root._pendingExitCode = exitCode
            root.fingerprintScanning = true
            scanFeedbackTimer.restart()
        }
    }

    // Brief delay between scan completion and result processing, giving the
    // UI time to show "scanning fingerprint..." feedback.
    Timer {
        id: scanFeedbackTimer
        interval: 300
        onTriggered: root.processScanResult()
    }

    function processScanResult() {
        root.fingerprintScanning = false
        var exitCode = root._pendingExitCode

        if (exitCode === 0) {
            root.fingerprintMatched = true
            root.fingerprintFailed = false
            root.unlocked()
            return
        }

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
