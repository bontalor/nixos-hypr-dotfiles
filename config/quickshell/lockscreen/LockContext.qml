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
    // verification happens out-of-band on the device. This mirrors how the
    // rest of the shell shells out to CLI tools (nmcli, curl, loginctl)
    // where no native Quickshell service exists.
    //
    // `fingerprintMatched` suppresses a late verify racing a password unlock;
    // `unlockInProgress` ignores the exit of a verify killed by tryUnlock
    // (a real match — exit 0 — still unlocks even mid-password-attempt);
    // `fingerprintEnabled` latches false when fprintd is missing or has no
    // usable device/enrolled prints, so the UI hides the indicator and the
    // retry loop stops spinning.
    property bool fingerprintEnabled: true
    property bool fingerprintMatched: false
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
        // process error — `onFinished` then covers every case uniformly.
        command: ["sh", "-c", "fprintd-verify"]
        stdout: StdioCollector { id: fprintOut }

        // fprintd-verify: exit 0 == verify-match, exit 1 == anything else
        // (no-match, no device, no enrolled fingers, daemon down, …).
        // Exit 127 == fprintd not installed. Stdout disambiguates the
        // recoverable exit-1 cases from the permanent ones. `exited` is
        // Process's only completion signal; `onFinished`/`onErrorOccurred`
        // exist as C++ virtual methods but aren't QML-assignable.
        onExited: (exitCode, exitStatus) => {
            if (root.fingerprintMatched) return
            // A match (exit 0) unlocks even mid-password-attempt; only
            // non-zero exits during an in-flight password attempt belong to
            // the verify process tryUnlock just killed, so ignore them.
            if (exitCode === 0) {
                root.fingerprintMatched = true
                root.unlocked()
                return
            }
            if (root.unlockInProgress) return

            var out = (fprintOut.text || "").toLowerCase()
            var unusable =
                exitCode === 127
                || out.indexOf("no fingers enrolled") >= 0
                || out.indexOf("no default device") >= 0
                || out.indexOf("impossible to verify") >= 0
                || out.indexOf("failed to connect to session bus") >= 0
                || out.indexOf("failed to get fprintd manager") >= 0
                || out.indexOf("listenrolledfingers failed") >= 0

            if (unusable) {
                // No reader, no prints, fprintd missing, or daemon down —
                // password is still the primary path; just stop pretending.
                root.fingerprintEnabled = false
                root.fingerprintHint = ""
                return
            }

            // Transient no-match / retry-scan / inactivity timeout — re-arm
            // shortly so the user can try again without re-typing.
            root.fingerprintHint = "no match — retry"
            retryTimer.restart()
        }
    }

    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: {
            if (root.fingerprintMatched || root.unlockInProgress
                || !root.fingerprintEnabled) return
            root.fingerprintHint = "or touch fingerprint"
            fprintProc.running = true
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
                // tryUnlock cancels any in-flight verify; without re-arming
                // here the reader stays dead after a wrong password.
                if (root.fingerprintEnabled && !root.fingerprintMatched) {
                    root.fingerprintHint = "or touch fingerprint"
                    fprintProc.running = true
                }
            }
        }
    }
}
