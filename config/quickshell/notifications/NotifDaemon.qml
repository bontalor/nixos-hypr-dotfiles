// Notification daemon — mako-like.
//
// Lives in the shell.qml Scope alongside the bar. Owns the Quickshell
// `NotificationServer`, exposes a `history` ListModel for the history
// panel, and raises popups via the live `activePopups` ListModel that
// `NotifPopup.qml` mirrors via Variants.
//
// Expiry/dismiss removes the popup but keeps the snapshot in `history`
// so the panel still shows it. Critical notifications don't auto-expire.
//
// Actions: left-clicking a popup invokes the sender's default action
// (mako-style — no buttons are rendered); right-click, or left-click on
// an actionless notification, dismisses. History is persisted to the
// state dir, so it survives shell restarts.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../util"

Singleton {
    id: root

    // Popup auto-expire follows the Settings pref (seconds).
    property int notifExpireMillis: PrefStore.notifExpireSec * 1000
    property int maxPopups: 3
    // History entries kept (oldest dropped) so a long session doesn't
    // accumulate snapshots unboundedly.
    property int notifHistoryMax: 100
    // Body lines shown before truncation (popup and collapsed history
    // entry alike); the history panel expands to the full text.
    property int notifBodyMaxLines: 3
    property int notifSummaryMaxLines: 2

    // Append-only history of snapshot objects.
    property ListModel history: ListModel {}

    property ListModel activePopups: ListModel {}

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
        // No action buttons are rendered, but the default action is
        // invokable by left-clicking the popup (invokeAction below), so
        // clients are told actions are supported.
        actionsSupported: true
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

    // Insert a snapshot into history (newest first, capped) and — unless
    // popups are disabled in Settings (do-not-disturb) and the
    // notification isn't critical — raise a popup (oldest popped off the
    // bottom past maxPopups). Shared by client and internal notifications.
    function addSnapshot(snap, urgency) {
        root.history.insert(0, snap)
        while (root.history.count > root.notifHistoryMax) {
            root.history.remove(root.history.count - 1)
        }
        root.persistHistory()
        if (PrefStore.notifPopups || urgency === NotificationUrgency.Critical) {
            root.activePopups.insert(0, snap)
            while (root.activePopups.count > root.maxPopups) {
                root.activePopups.remove(root.activePopups.count - 1)
            }
        }
    }

    function handleNotification(notification) {
        // Snapshot schema matches for history and popups, so the panel
        // and popups see the same fields. History records even in
        // do-not-disturb, and the expire/close lifecycle below runs
        // unchanged so senders see normal notification semantics.
        root.addSnapshot(root.snapshot(notification), notification.urgency)

        // Track the notification so its `closed` signal fires when
        // we expire/dismiss it.
        notification.tracked = true

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
        return root.notifExpireMillis
    }

    // Shell-internal notification (low battery, failed command, …) —
    // same snapshot schema and popup/DND/expiry semantics as a client
    // notification, minus the D-Bus round trip. Ids are negative so
    // they can never collide with server-assigned ones.
    property int _nextInternalId: -1

    function notify(summary, body, urgency) {
        var snap = {
            notifId: root._nextInternalId--,
            summary: summary || "",
            body: body || "",
            appName: "Shell",
            appIcon: "",
            image: "",
            urgency: urgency,
            timestamp: Date.now(),
            hasAction: false
        }
        root.addSnapshot(snap, urgency)
        if (urgency !== NotificationUrgency.Critical)
            root.scheduleExpire({ id: snap.notifId }, root.notifExpireMillis)
    }

    function scheduleExpire(notification, ms) {
        root.pendingExpiries[notification.id] = {
            notification: notification,
            notifId: notification.id,
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
            // Internal notifications have no server object to expire —
            // drop their popup directly.
            if (entry.notification.expire) {
                try { entry.notification.expire() } catch (e) {}
            } else {
                root.removePopupById(entry.notifId)
            }
        }
        root.pendingCount = Object.keys(root.pendingExpiries).length
    }

    // Invoke the sender's default action (the one a click means, per the
    // spec's "default" identifier convention; first listed otherwise) and
    // dismiss. Falls back to a plain dismiss when the notification has no
    // actions or is no longer tracked.
    function invokeAction(notifId) {
        var tracked = server.trackedNotifications
        var values = tracked ? tracked.values : []
        for (var i = 0; i < values.length; i++) {
            if (values[i].id !== notifId) continue
            var acts = values[i].actions
            if (acts && acts.length > 0) {
                var act = acts[0]
                for (var j = 0; j < acts.length; j++) {
                    if (acts[j].identifier === "default") { act = acts[j]; break }
                }
                act.invoke()
                values[i].dismiss()
                return
            }
            break
        }
        root.dismissPopup(notifId)
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

    function clearHistory() {
        root.history.clear()
        root.persistHistory()
    }

    // Single schema for both history and activePopups snapshots —
    // includes appIcon/image so the panel can render them too.
    // `hasAction` drives the popup's left-click behavior (invoke vs
    // dismiss); it is forced false for entries reloaded from disk since
    // the server-side action objects don't survive a restart.
    function snapshot(n) {
        return {
            notifId: n.id,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: n.image || "",
            urgency: n.urgency,
            timestamp: Date.now(),
            hasAction: (n.actions ? n.actions.length : 0) > 0
        }
    }

    // --- History persistence (state dir, same FileView+JsonAdapter
    // pattern as ClipboardModel). Newest first, capped at
    // notifHistoryMax; rewritten on every change. Because every
    // snapshot is persisted as it lands, the history survives both
    // config reloads and full shell restarts.
    function persistHistory() {
        var out = []
        for (var i = 0; i < root.history.count; i++) {
            var e = root.history.get(i)
            out.push({
                notifId: e.notifId, summary: e.summary, body: e.body,
                appName: e.appName, appIcon: e.appIcon, image: e.image,
                urgency: e.urgency, timestamp: e.timestamp, hasAction: false
            })
        }
        histStore.entries = out
    }

    Component.onCompleted: {
        var es = histStore.entries || []
        for (var i = 0; i < es.length && i < root.notifHistoryMax; i++) {
            var e = es[i]
            root.history.append({
                notifId: e.notifId ?? 0,
                summary: e.summary ?? "",
                body: e.body ?? "",
                appName: e.appName ?? "",
                appIcon: e.appIcon ?? "",
                image: e.image ?? "",
                urgency: e.urgency ?? NotificationUrgency.Normal,
                timestamp: e.timestamp ?? 0,
                hasAction: false
            })
        }
    }

    FileView {
        path: Paths.stateDir + "/notif-history.json"
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: histStore
            property var entries: []
        }
    }
}
