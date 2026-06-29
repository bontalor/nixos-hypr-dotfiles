// Notification daemon — mako-like.
//
// Lives in the shell.qml Scope alongside the bar. Owns the Quickshell
// `NotificationServer`, exposes a `history` ListModel for the history
// panel, and raises popups via the live `activePopups` ListModel that
// `NotifPopup.qml` mirrors via Variants.
//
// Expiry/dismiss removes the popup but keeps the snapshot in `history`
// so the panel still shows it. Critical notifications don't auto-expire.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Append-only history of snapshot objects.
    property ListModel history: ListModel {}

    property ListModel activePopups: ListModel {}
    property int maxPopups: 3

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        onNotification: function(n) { root.handleNotification(n) }
    }

    // One-shot Timer reused for auto-expire. Restarting it just resets
    // the countdown; we keep one timer per concurrent popup by tracking
    // them in a small array of {id, timer} pairs.
    function handleNotification(notification) {
        // Snapshot into history (newest first).
        root.history.insert(0, root.snapshot(notification))

        // Track the notification so its `closed` signal fires when
        // we expire/dismiss it.
        notification.tracked = true

        root.activePopups.insert(0, {
            notifId: notification.id,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            appIcon: notification.appIcon,
            urgency: notification.urgency,
            image: notification.image || "",
            timestamp: Date.now()
        })

        // Cap popup count (oldest popped off the bottom).
        while (root.activePopups.count > root.maxPopups) {
            root.activePopups.remove(root.activePopups.count - 1)
        }

        // Auto-expire per the sender's request, unless critical.
        var ms = root.expireMillis(notification)
        if (ms > 0) root.scheduleExpire(notification, ms)

        // Wire up the notification's `closed` signal so external
        // dismissals (from the panel/another client) drop the popup.
        var cb = function() {
            root.removePopupById(notification.id)
            try { notification.closed.disconnect(cb) } catch (e) {}
        }
        notification.closed.connect(cb)
    }

    function expireMillis(notification) {
        if (notification.urgency === NotificationUrgency.Critical) return 0
        return 5000
    }

    function scheduleExpire(notification, ms) {
        // Single-shot Timer. Created on demand — parented to the
        // singleton itself, so it dies with the daemon.
        var timer = Qt.createQmlObject("import QtQuick; Timer {}", root, "notif-expire-timer")
        timer.interval = ms
        timer.repeat = false
        timer.triggered.connect(function() {
            try { notification.expire() } catch (e) {}
            timer.destroy()
        })
        timer.start()
    }

    function dismissPopup(notifId) {
        var tracked = server.trackedNotifications
        var values = tracked ? tracked.values : []
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === notifId) { values[i].dismiss(); return }
        }
        root.removePopupById(notifId)
    }

    function removePopupById(notifId) {
        for (var i = 0; i < root.activePopups.count; i++) {
            if (root.activePopups.get(i).notifId === notifId) {
                root.activePopups.remove(i)
                return
            }
        }
    }

    function clearHistory() { root.history.clear() }

    function snapshot(n) {
        return {
            notifId: n.id,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            urgency: n.urgency,
            timestamp: Date.now()
        }
    }
}