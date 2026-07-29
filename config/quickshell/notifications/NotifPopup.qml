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
    WlrLayershell.namespace: "quickshell:notification"
    WlrLayershell.anchors { top: true; right: true }
    WlrLayershell.margins { top: 20; right: Theme.margin + 20 }

    color: "transparent"
    implicitWidth: Theme.popupWidthWithShadow
    implicitHeight: popupColumn.implicitHeight
    visible: NotifDaemon.activePopups.count > 0 && !fullscreenActive

    property bool fullscreenActive: ToplevelManager.activeToplevel
        ? ToplevelManager.activeToplevel.fullscreen : false
    // Mirror fullscreenActive into the daemon so it can defer expiry
    // of popups sent during a fullscreen session (otherwise they expire
    // invisibly and disappear before the user ever sees them).
    onFullscreenActiveChanged: NotifDaemon.fullscreenActive = fullscreenActive
    Component.onCompleted: NotifDaemon.fullscreenActive = fullscreenActive

    Column {
        id: popupColumn
        width: parent.width
        spacing: Theme.margin

        Repeater {
            model: NotifDaemon.activePopups

            delegate: PopupCard {
                id: card
                required property string summary
                required property string body
                required property string appName
                required property string appIcon
                required property string image
                required property int notifId
                required property int urgency
                required property bool hasAction

                width: parent.width
                // Grows with the (line-capped) text; never smaller than
                // the standard popup so short notifications keep the
                // usual shape. Includes the card's shadow extent.
                height: Math.max(Theme.popupHeight,
                                 contentRow.implicitHeight + 3 * Theme.margin)
                border.width: urgency === NotificationUrgency.Critical ? 2 : 0
                border.color: Colors.critical

                Row {
                    id: contentRow
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: Theme.margin; rightMargin: Theme.margin; topMargin: Theme.margin
                    }
                    spacing: Theme.margin

                    // App icon — resolved through the desktop entry /
                    // icon theme via IconImage (same widget the history
                    // panel uses). Falls back to the sender's embedded
                    // image (album cover, screenshot) when no app icon
                    // is resolvable, matching the history panel.
                    NotifIcon {
                        id: popupIcon
                        appIcon: card.appIcon
                        image: card.image
                    }

                    Column {
                        width: parent.width - (popupIcon.resolved ? Theme.iconSize + Theme.margin : 0)
                        spacing: Theme.margin

                        ThemeText {
                            width: parent.width
                            text: card.summary || ""
                            font.bold: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: NotifDaemon.notifSummaryMaxLines
                            elide: Text.ElideRight
                        }

                        ThemeText {
                            width: parent.width
                            text: card.body || ""
                            wrapMode: Text.WordWrap
                            maximumLineCount: NotifDaemon.notifBodyMaxLines
                            elide: Text.ElideRight
                            visible: text !== ""
                        }
                    }
                }

                // Left-click invokes the sender's default action when it
                // has one (pointer cursor signals that); right-click, or
                // left-click on an actionless notification, dismisses.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: card.hasAction ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton && card.hasAction)
                            NotifDaemon.invokeAction(card.notifId)
                        else
                            NotifDaemon.dismissPopup(card.notifId)
                    }
                }
            }
        }
    }
}
