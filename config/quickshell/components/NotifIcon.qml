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
    readonly property bool resolved: appIcon !== "" && icon.status === Image.Ready
        || (icon.source === "" && fallback.status === Image.Ready)

    IconImage {
        id: icon
        source: root.appIcon
        visible: root.appIcon !== "" && status !== Image.Error
        width: Theme.iconSize; height: Theme.iconSize
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