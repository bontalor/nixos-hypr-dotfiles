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

    property var powerProfiles: BatteryModel.profiles
    property bool profileDaemonAvailable: BatteryModel.profileIndex >= 0

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return BatteryModel.batteryDevices.length
        case 1: return root.powerProfiles.count
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        if (root.selSection === 0) {
            var dev = BatteryModel.batteryDevices[idx]
            if (dev) BatteryModel.selectDevice(dev.nativePath)
        } else if (root.selSection === 1) {
            var entry = root.powerProfiles.get(idx)
            if (entry) BatteryModel.setProfile(entry.enumVal)
        }
    }

    // ---- Section 0: Battery list ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Text {
            width: parent.width
            height: Theme.searchRowHeight
            visible: BatteryModel.batteryDevices.length === 0
            text: "No batteries detected"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
        }

        Repeater {
            model: BatteryModel.batteryDevices

            delegate: Item {
                width: parent.width
                height: root.rowHeight
                required property var modelData
                required property int index

                property bool isActive: BatteryModel.activeDevice === modelData
                property int pct: Math.round(modelData.percentage * 100)

                Rectangle {
                    anchors.fill: parent
                    color: root.inSection && index === root.selDevice ? Qt.alpha(Colors.base01, Theme.alphaSelected) : "transparent"
                }

                Text {
                    id: devName
                    text: BatteryModel.deviceName(modelData)
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: isActive ? Colors.base0b : Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: isActive
                }

                Text {
                    text: pct + "%"
                    anchors { left: devName.right; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: pct <= Theme.batteryCritical ? Colors.base08
                        : pct <= Theme.batteryWarning ? Colors.base09
                        : Colors.foreground
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                    font.bold: true
                }

                Text {
                    text: {
                        var s = BatteryModel.stateText(modelData)
                        return s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
                    }
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: modelData.state === UPowerDeviceState.Charging ? Colors.base0b
                        : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                    font.pixelSize: Theme.fontPixelSize
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.inSection) { root.inSection = true; root.selDevice = index }
                        BatteryModel.selectDevice(modelData.nativePath)
                    }
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
                        if (!isActive) BatteryModel.setProfile(enumVal)
                    }
                }
            }
        }
    }
}
