// Notification daemon — mako-like.
//
// Lives in the shell.qml Scope alongside the bar. Owns the Quickshell
// `NotificationServer`, exposes a `history` ListModel for the history
// panel, and raises popups by spawning one NotifPopup PanelWindow per
// active notification. Each popup Window is created via Component
// .createObject with the snapshot's fields baked in as concrete
// properties — there is no shared ListModel + Repeater driving them,
// so when a popup despawns the surviving windows only have their numeric
// `WlrLayershell.margins.top` adjusted (recomputed by popupYOffset);
// their Text / IconImage never rebind, killing the previous
// "remaining two popups flicker for a split second when one despawns"
// symptom at both causes (QML row-shift rebind and Wayland-surface
// resize/reattach on a shared surface).
//
// Expiry/dismiss removes the popup but keeps the snapshot in `history`
// so the panel still shows it. Critical notifications don't auto-expire.
//
// Actions: left-clicking a popup invokes the sender's default action
// (mako-style — no buttons are rendered); right-click, or left-click on
// an actionless notification, dismisses. History is persisted to the
// state dir, so it survives shell restarts.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../theme"
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

    // Active popup Windows keyed by notifId — concrete NotifPopup
    // instances with their snapshot fields assigned at createObject()
    // time (no model bindings). `popupOrder` is the newest-first list
    // of notifIds tracking vertical layout; `popupLayoutVersion` is
    // bumped on every add/remove so popup Y-offset bindings re-evaluate
    // without each popup having to subscribe to sibling implicitHeight
    // changes individually (the function also creates implicit deps on
    // sibling implicitHeights via QML's binding read-tracking once it
    // runs, so re-layout fires when any popup's card height settles).
    property var popupSurfaces: ({})   // String(notifId) -> NotifPopup instance
    property var popupOrder: []        // int notifIds, newest first
    property int popupLayoutVersion: 0

    // Component used to spawn popup Windows on demand. Parsed once from
    // the relative URL (resolved against NotifDaemon.qml's directory).
    property Component popupComponent: Qt.createComponent("NotifPopup.qml")

    // Pending expiries keyed by notifId. A single recurring Timer scans
    // this map and calls notification.expire() on due entries — replaces
    // the prior per-notification Qt.createQmlObject("Timer {}", ...)
    // anti-pattern (no static analysis, per-notif QObject allocation).
    //
    // Each entry shape: { notification, notifId, expireAt, expireMs }.
    // - `expireAt`: epoch-ms when the entry becomes due, or -1 to mean
    //   "deferred while a toplevel is fullscreen" — the scan timer
    //   skips these. Re-armed when fullscreen ends (so the popup gets
    //   its full lifetime once the user can actually see it).
    // - `expireMs`: original requested lifetime, used to re-arm.
    property var pendingExpiries: ({})

    // Mirror of the map's size (plain-object mutations don't notify) so
    // the scan timer only runs while something is actually pending.
    property int pendingCount: 0

    // True while any toplevel is fullscreened (mirrored from NotifPopup's
    // binding). Expiry of normal popups is deferred until fullscreen ends
    // so notifications sent during a fullscreen session aren't silently
    // dropped while the popup window is invisible.
    property bool fullscreenActive: false
    onFullscreenActiveChanged: if (!fullscreenActive) root.rearmDeferredExpiries()

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
            root.spawnPopup(snap)
            // Overflow: drop the oldest (visually bottom) popup Window.
            while (root.popupOrder.length > root.maxPopups) {
                root.despawnPopupById(root.popupOrder[root.popupOrder.length - 1])
            }
        }
    }

    // Spawn a fresh popup Window with the snapshot baked in as concrete
    // properties. Lifetime is tied to the daemon (passed as the QObject
    // parent) — destroyed with the singleton on shell reload, and
    // explicitly destroyed via despawnPopupById on dismiss/expire.
    function spawnPopup(snap) {
        var inst = root.popupComponent.createObject(root, {
            notifId:       snap.notifId,
            notifSummary:  snap.summary,
            notifBody:     snap.body,
            notifAppName:  snap.appName,
            notifAppIcon:  snap.appIcon,
            notifImage:    snap.image,
            notifUrgency:  snap.urgency,
            notifHasAction: snap.hasAction
        })
        if (!inst) {
            console.warn("NotifPopup spawn failed:",
                         root.popupComponent.errorString())
            return
        }
        root.popupSurfaces[String(snap.notifId)] = inst
        root.popupOrder.unshift(snap.notifId)
        root.popupLayoutVersion++
    }

    // Destroy a popup Window by notifId and recompute sibling Y offsets
    // ( popupLayoutVersion bump re-evaluates surviving bindings ). The
    // snapshot stays in `history`.
    function despawnPopupById(notifId) {
        var inst = root.popupSurfaces[String(notifId)]
        if (!inst) return
        delete root.popupSurfaces[String(notifId)]
        var idx = root.popupOrder.indexOf(notifId)
        if (idx >= 0) root.popupOrder.splice(idx, 1)
        inst.destroy()
        root.popupLayoutVersion++
    }

    // Cumulative Y offset (including the 20px top screen margin handled
    // by each popup's own binding) for the popup identified by `id`,
    // summing the implicitHeight of preceding popups in stack order.
    // Reading `popupLayoutVersion` makes the binding depend on layout
    // changes; reading each preceding `inst.implicitHeight` adds a
    // per-popup reactive dependency so card-height settling re-fires.
    function popupYOffset(id) {
        var _v = root.popupLayoutVersion
        var y = 0
        for (var i = 0; i < root.popupOrder.length; i++) {
            var cur = root.popupOrder[i]
            if (cur === id) break
            var inst = root.popupSurfaces[String(cur)]
            if (inst) y += inst.implicitHeight + Theme.margin
        }
        return y
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
        // Defer while fullscreen — the popup window isn't visible, so
        // `expireAt` is left at -1 (sentinel) and re-armed to
        // `Date.now() + ms` when fullscreen ends.
        root.pendingExpiries[notification.id] = {
            notification: notification,
            notifId: notification.id,
            expireAt: root.fullscreenActive ? -1 : Date.now() + ms,
            expireMs: ms
        }
        root.pendingCount = Object.keys(root.pendingExpiries).length
    }

    // Re-arm any deferred (-1) expiries when fullscreen ends so the
    // notifications get their full lifetime visible to the user.
    function rearmDeferredExpiries() {
        var now = Date.now()
        for (var id in root.pendingExpiries) {
            if (root.pendingExpiries[id].expireAt === -1) {
                root.pendingExpiries[id].expireAt = now + root.pendingExpiries[id].expireMs
            }
        }
    }

    function scanExpiries() {
        var now = Date.now()
        var due = []
        for (var id in root.pendingExpiries) {
            var entry = root.pendingExpiries[id]
            // Skip deferred entries (during fullscreen) — they're not
            // ticking down. They'll be re-armed when fullscreen ends.
            if (entry.expireAt === -1) continue
            if (entry.expireAt <= now) due.push(id)
        }
        for (var i = 0; i < due.length; i++) {
            var e = root.pendingExpiries[due[i]]
            delete root.pendingExpiries[due[i]]
            // Internal notifications have no server object to expire —
            // drop their popup directly.
            if (e.notification.expire) {
                try { e.notification.expire() } catch (e2) {}
            } else {
                root.removePopupById(e.notifId)
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
        // Cancel any pending expiry for this id — otherwise the timer
        // keeps running for a dismissed notification, and the eventual
        // expire() call hits an already-dismissed server object.
        if (root.pendingExpiries[notifId] !== undefined) {
            delete root.pendingExpiries[notifId]
            root.pendingCount = Object.keys(root.pendingExpiries).length
        }
        var tracked = server.trackedNotifications
        var values = tracked ? tracked.values : []
        for (var i = 0; i < values.length; i++) {
            if (values[i].id === notifId) { values[i].dismiss(); return }
        }
        root.removePopupById(notifId)
    }

    function removePopupById(notifId) {
        root.despawnPopupById(notifId)
    }

    function clearHistory() {
        root.history.clear()
        root.persistHistory()
    }

    // Single schema for both history and popup snapshots —
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
    FileView {
        id: histFile
        path: Paths.stateDir + "/notif-history.json"
        blockLoading: true
        atomicWrites: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: histStore
            property var entries: []
        }

        property alias histEntries: histStore.entries
    }

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
        histFile.histEntries = out
    }

    Component.onCompleted: {
        var es = histFile.histEntries || []
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
}
