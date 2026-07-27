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
    // Y offset within the popup stack is bound to the daemon's layout
    // function so each window repositions on sibling despawn without
    // touching its own content bindings.
    WlrLayershell.margins.top: 20 + NotifDaemon.popupYOffset(notifId)
    WlrLayershell.margins.right: Theme.margin + 20

    color: "transparent"
    implicitWidth: Theme.popupWidthWithShadow
    implicitHeight: card.height
    visible: !fullscreenActive

    property bool fullscreenActive: ToplevelManager.activeToplevel
        ? ToplevelManager.activeToplevel.fullscreen : false
    // Mirror fullscreenActive into the daemon so it can defer expiry
    // of popups sent during a fullscreen session (otherwise they expire
    // invisibly and disappear before the user ever sees them).
    onFullscreenActiveChanged: NotifDaemon.fullscreenActive = fullscreenActive
    Component.onCompleted: NotifDaemon.fullscreenActive = fullscreenActive

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
                width: parent.width - (popupIcon.resolved ? Theme.iconSize + Theme.margin : 0)
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