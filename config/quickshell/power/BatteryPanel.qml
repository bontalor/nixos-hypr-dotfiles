import "../theme"
import "../models"
import QtQuick
import Quickshell.Services.UPower

Panel {
    id: root
    title: "Battery & Power"
    sections: [
        { name: "Battery" },
        { name: "Power Profiles" }
    ]

    // Live D-Bus-backed state from BatteryModel.
    property int batteryPercent: BatteryModel.percentage
    property string batteryState: {
        if (!BatteryModel.displayDevice) return ""
        switch (BatteryModel.displayDevice.state) {
        case UPowerDeviceState.Charging:        return "charging"
        case UPowerDeviceState.Discharging:     return "discharging"
        case UPowerDeviceState.FullyCharged:    return "fully-charged"
        case UPowerDeviceState.Empty:           return "empty"
        case UPowerDeviceState.PendingCharge:  return "pending-charge"
        case UPowerDeviceState.PendingDischarge: return "pending-discharge"
        default: return "unknown"
        }
    }
    property string batteryModel: BatteryModel.displayDevice ? (BatteryModel.displayDevice.model || "") : ""

    property var powerProfiles: BatteryModel.profiles
    property string activeProfile: BatteryModel.activeProfile
    property bool profileDaemonAvailable: BatteryModel.profileIndex >= 0

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return root.batteryPercent >= 0 ? 1 : 0
        case 1: return root.powerProfiles.count
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        if (root.selSection === 1) {
            var entry = root.powerProfiles.get(idx)
            if (entry) BatteryModel.setProfile(entry.name)
        }
    }

    // ---- Section 0: Battery summary ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Rectangle {
            width: parent.width
            height: root.rowHeight + (root.batteryPercent >= 0 ? 30 * 2 : 0)
            color: root.inSection && 0 === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"

            Column {
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                spacing: 2

                Text {
                    text: root.batteryModel || "Battery"
                    color: Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: true
                    visible: root.batteryPercent >= 0
                }

                Text {
                    visible: root.batteryPercent >= 0
                    text: {
                        var plugged = BatteryModel.charging || batteryState === "fully-charged" || batteryState === "pending-charge"
                        var prefix = plugged ? Icon.plug + " " : ""
                        var s = root.batteryState
                            ? root.batteryState.charAt(0).toUpperCase() + root.batteryState.slice(1)
                            : ""
                        return prefix + s
                    }
                    color: BatteryModel.charging
                        ? Colors.base0b
                        : (root.batteryPercent <= Theme.batteryCritical ? Colors.base08 : Qt.alpha(Colors.foreground, Theme.alphaBackground))
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                Text {
                    visible: root.batteryPercent >= 0
                    text: root.batteryPercent + "%"
                    color: {
                        if (root.batteryPercent <= Theme.batteryCritical) return Colors.base08
                        if (root.batteryPercent <= Theme.batteryWarning) return Colors.base09
                        return Colors.foreground
                    }
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Text {
                    visible: root.batteryPercent < 0
                    text: "No battery detected"
                    color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }
            }
        }
    }

    // ---- Section 1: Power Profiles ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: !root.profileDaemonAvailable
            text: "power-profiles-daemon not available"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }

        Repeater {
            model: root.powerProfiles
            visible: root.profileDaemonAvailable

            delegate: Item {
                width: parent.width
                height: root.rowHeight
                required property string name
                required property int enumVal
                required property string icon
                required property int index

                property bool isActive: BatteryModel.profileIndex === enumVal

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                Row {
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    Text {
                        text: icon
                        color: isActive ? Colors.base0b : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: name
                        color: isActive ? Colors.base0b : Colors.foreground
                        font.pixelSize: Theme.fontPixelSize
                        font.family: Theme.fontFamily
                        font.bold: isActive
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: isActive ? "Active" : ""
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.base0b
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index }
                        if (!isActive) BatteryModel.setProfile(name)
                    }
                }
            }
        }
    }
}