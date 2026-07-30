// Shared sender-icon widget for notification surfaces (popup + history).
//
// Resolves `appIcon` through the icon theme via IconImage (the same
// widget both call sites used before extraction); if resolution fails
// or `appIcon` is empty, falls back to the notification's embedded
// image (album cover, screenshot). Exposes `resolved` so the caller
// can size its text column to match the icon slot's width.
//
// Replaces two near-identical 15-line stacks in NotifPopup and
// NotifHistoryPanel with subtly different column-width computations.
import "../theme"
import QtQuick
import Quickshell.Widgets

Item {
    id: root

    required property string appIcon
    required property string image

    width: root.resolved ? Theme.iconSize : 0
    height: Theme.iconSize

    // True when either icon source rendered successfully — the caller
    // reserves `Theme.iconSize + Theme.margin` column width for the icon.
    // Parentheses matter: the previous unparenthesized form required
    // `icon.source === ""` for the fallback clause, but `icon.source` is
    // `appIcon` (non-empty whenever an appIcon is set), so a named-app
    // notification whose theme lookup failed (icon.status === Error)
    // collapsed the slot to width 0 even when the embedded image had
    // loaded via the fallback `Image` below.
    readonly property bool resolved: (appIcon !== "" && icon.status === Image.Ready)
        || (image !== "" && fallback.status === Image.Ready)

    // Whether an icon is *expected* (appIcon or embedded image present),
    // independent of whether it has finished loading. Used by callers
    // (NotifPopup) to reserve the icon column slot from creation so the
    // text column width — and therefore the popup's implicitHeight —
    // never re-settles as the icon asynchronously resolves. Without
    // this, surviving popups reposition their Wayland surface multiple
    // times as a fresh popup's height oscillates (the "flicker when a
    // new popup spawns" symptom); this mirrors why despawn is already
    // seamless (surviving popups all have settled heights by then).
    readonly property bool expectsIcon: appIcon !== "" || image !== ""

    IconImage {
        id: icon
        source: root.appIcon
        visible: root.appIcon !== "" && status !== Image.Error
        width: Theme.iconSize; height: Theme.iconSize
        // 2px inset from the slot top — the icon's font baseline leaves
        // a small gap when anchored flush; this matches the perceived
        // centering of the surrounding Row's verticalCenter.
        anchors { top: parent.top; topMargin: 2; left: parent.left }
    }

    Image {
        id: fallback
        source: root.image
        visible: root.image !== "" && icon.status !== Image.Ready && status !== Image.Error
        width: Theme.iconSize; height: Theme.iconSize
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        anchors { top: parent.top; topMargin: 2; left: parent.left }
    }
}