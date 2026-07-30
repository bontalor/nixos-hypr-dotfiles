// One Wayland surface per active notification. Spawned on demand by
// NotifDaemon (no shared ListModel / Repeater) — each popup Window holds
// its snapshot in concrete properties set at createObject() time, so when
// a sibling popup despawns the surviving windows never rebind their
// content and never re-resolve their IconImage; only the numeric
// `WlrLayershell.margins.top` shifts (recomputed by NotifDaemon.popupYOffset)
// as the stack rearranges. That avoids the previous "remaining popups
// flicker for a split second when one despawns" symptom at both causes:
// no QML Repeater row-shift rebind, and no shared Wayland-surface
// resize/reattach on despawn.

import "../theme"
import "../components"
import "."
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets

PanelWindow {
    id: root

    // Snapshot — assigned once at createObject() and never rebound to a
    // fluctuating model row, so repositioning on a sibling despawn never
    // re-resolves the icon or re-renders the text.
    property int notifId
    property string notifSummary
    property string notifBody
    property string notifAppName
    property string notifAppIcon
    property string notifImage
    property int notifUrgency
    property bool notifHasAction

    WlrLayershell.namespace: "quickshell:notification"
    WlrLayershell.anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    // Y offset within the popup stack is assigned explicitly by
    // NotifDaemon.relayoutPopups() — NOT bound to a function of sibling
    // implicitHeights. A binding that reads sibling `implicitHeight`
    // re-evaluates each time the sibling's Row polish settles the card
    // height (a multi-step settle that spans several frames at 144hz),
    // so the surviving windows' Wayland surfaces reposition repeatedly
    // → visible flicker; at 60hz the settle completes within one frame
    // so the same binding reads as a single jump (which is why despawn,
    // where heights are already settled, never flickered either). The
    // daemon now relayouts explicitly: a debounced single assignment on
    // spawn (after the new popup's height has settled) and a synchronous
    // single assignment on despawn, killing the spawn-time oscillation
    // while preserving despawn's "seamless single jump" feel.
    property int yOffset: 0
    // Vertical screen anchor: 20 px below the bar (bar bottom edge ≈
    // y=50 from screen top, so the popup's top edge sits at y≈80).
    // `yOffset` adds the cumulative stack offset assigned by
    // NotifDaemon.relayoutPopups().
    WlrLayershell.margins.top: Theme.barMargin + Theme.barHeight + Theme.margin + 20 + root.yOffset
    WlrLayershell.margins.right: Theme.margin + 20

    color: "transparent"
    implicitWidth: Theme.popupWidthWithShadow
    implicitHeight: card.height
    visible: !fullscreenActive

    // When this popup's height settles (because the Row that hosts the
    // text/icon is initially aspirational until Qt's polish pass runs),
    // ask the daemon to relayout the stack — once. The daemon's relayout
    // debounce coalesces multi-step settles into a single relayout so
    // sibling popups jump once instead of flickering (see the Y-offset
    // comment above).
    onImplicitHeightChanged: NotifDaemon.scheduleRelayout()

    PopupCard {
        id: card
        width: parent.width
        // Grows with the (line-capped) text; never smaller than the
        // standard popup so short notifications keep the usual shape.
        // Includes the card's shadow extent.
        height: Math.max(Theme.popupHeight,
                         contentRow.implicitHeight + 3 * Theme.margin)
        border.width: notifUrgency === NotificationUrgency.Critical ? 2 : 0
        border.color: Colors.critical

        Row {
            id: contentRow
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: Theme.margin; rightMargin: Theme.margin; topMargin: Theme.margin
            }
            spacing: Theme.margin

            // App icon — resolved through the desktop entry / icon theme
            // via IconImage (same widget the history panel uses). Falls
            // back to the sender's embedded image (album cover,
            // screenshot) when no app icon is resolvable, matching the
            // history panel.
            NotifIcon {
                id: popupIcon
                appIcon: root.notifAppIcon
                image: root.notifImage
            }

            Column {
                // Reserve the icon column based on `expectsIcon`, not
                // `resolved`: the column width (and so the text wrap, which
                // dictates contentRow.implicitHeight → card.height → the
                // popup's implicitHeight) is stable from creation instead
                // of re-settling once the icon asynchronously resolves.
                // This makes the only remaining spawn-time height change
                // the initial Row polish (handled by NotifDaemon's
                // debounce relayout), not a second async flip.
                width: parent.width - (popupIcon.expectsIcon ? Theme.iconSize + Theme.margin : 0)
                spacing: Theme.margin

                ThemeText {
                    width: parent.width
                    text: root.notifSummary || ""
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: NotifDaemon.notifSummaryMaxLines
                    elide: Text.ElideRight
                }

                ThemeText {
                    width: parent.width
                    text: root.notifBody || ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: NotifDaemon.notifBodyMaxLines
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // Left-click invokes the sender's default action when it has one
        // (pointer cursor signals that); right-click, or left-click on
        // an actionless notification, dismisses.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.notifHasAction ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && root.notifHasAction)
                    NotifDaemon.invokeAction(root.notifId)
                else
                    NotifDaemon.dismissPopup(root.notifId)
            }
        }
    }
}