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
import "../theme"

Singleton {
    id: root

    // Append-only history of snapshot objects.
    property ListModel history: ListModel {}

    property ListModel activePopups: ListModel {}
    property int maxPopups: Theme.maxPopups

    // Pending expiries keyed by notifId. A single recurring Timer scans
    // this map and calls notification.expire() on due entries — replaces
    // the prior per-notification Qt.createQmlObject("Timer {}", ...)
    // anti-pattern (no static analysis, per-notif QObject allocation).
    property var pendingExpiries: ({})

    // Mirror of the map's size (plain-object mutations don't notify) so
    // the scan timer only runs while something is actually pending.
    property int pendingCount: 0

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        // actionsSupported is false because no action-button UI is
        // rendered. Clients that send action buttons have them silently
        // dropped; setting false here tells them not to bother.
        actionsSupported: false
        onNotification: function(n) { root.handleNotification(n) }
    }

    // Single recurring timer that scans pendingExpiries for due entries.
    // 1s granularity matches the OSD hide timer and is fine for 5s expiries.
    // Gated on pendingCount so the shell is fully idle with no popups up.
    Timer {
        interval: 1000
        repeat: true
        running: root.pendingCount > 0
        onTriggered: root.scanExpiries()
    }

    function handleNotification(notification) {
        // Snapshot into history (newest first). Schema matches the
        // activePopups snapshot so the panel and popups see the same fields.
        root.history.insert(0, root.snapshot(notification))

        // Track the notification so its `closed` signal fires when
        // we expire/dismiss it.
        notification.tracked = true

        root.activePopups.insert(0, root.snapshot(notification))

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
        return Theme.notifExpireMillis
    }

    function scheduleExpire(notification, ms) {
        root.pendingExpiries[notification.id] = {
            notification: notification,
            expireAt: Date.now() + ms
        }
        root.pendingCount = Object.keys(root.pendingExpiries).length
    }

    function scanExpiries() {
        var now = Date.now()
        var due = []
        for (var id in root.pendingExpiries) {
            if (root.pendingExpiries[id].expireAt <= now) due.push(id)
        }
        for (var i = 0; i < due.length; i++) {
            var entry = root.pendingExpiries[due[i]]
            delete root.pendingExpiries[due[i]]
            try { entry.notification.expire() } catch (e) {}
        }
        root.pendingCount = Object.keys(root.pendingExpiries).length
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

    // Remove a single history entry by index. View code should call
    // this instead of mutating the singleton model directly.
    function removeFromHistory(idx) {
        if (idx >= 0 && idx < root.history.count) root.history.remove(idx)
    }

    // Single schema for both history and activePopups snapshots —
    // includes appIcon/image so the panel can render them too.
    function snapshot(n) {
        return {
            notifId: n.id,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: n.image || "",
            urgency: n.urgency,
            timestamp: Date.now()
        }
    }
}
