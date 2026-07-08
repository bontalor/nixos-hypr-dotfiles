import "../theme"
import "../components"
import "../models"
import "../util"
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
        case 1: return root.powerProfiles.length
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        if (root.selSection === 0) {
            var dev = BatteryModel.batteryDevices[idx]
            if (dev) BatteryModel.selectDevice(dev.nativePath)
        } else if (root.selSection === 1) {
            var entry = root.powerProfiles[idx]
            if (entry) BatteryModel.setProfile(entry.enumVal)
        }
    }

    // ---- Section 0: Battery list ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        EmptyLabel {
            visible: BatteryModel.batteryDevices.length === 0
            text: "No batteries detected"
        }

        Repeater {
            model: BatteryModel.batteryDevices

            delegate: PanelRow {
                width: parent.width
                height: root.rowHeight
                required property var modelData
                required property int index

                property bool isActive: BatteryModel.activeDevice === modelData
                property int pct: Math.round(modelData.percentage * 100)

                selected: root.inSection && index === root.selDevice
                panel: root
                itemIndex: index
                onClicked: BatteryModel.selectDevice(modelData.nativePath)

                ThemeText {
                    id: devName
                    text: BatteryModel.deviceName(modelData)
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: isActive ? Colors.success : Colors.foreground
                    font.bold: isActive
                }

                ThemeText {
                    text: pct + "%"
                    anchors { left: devName.right; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: pct <= BatteryModel.batteryCritical ? Colors.critical
                        : pct <= BatteryModel.batteryWarning ? Colors.warning
                        : Colors.foreground
                    font.bold: true
                }

                ThemeText {
                    text: {
                        var s = BatteryModel.stateText(modelData)
                        s = s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
                        // UPower's native estimate; 0 while unknown.
                        var t = FormatUtil.fmtDuration(
                            modelData.state === UPowerDeviceState.Charging
                                ? modelData.timeToFull : modelData.timeToEmpty)
                        return t ? s + " · " + t : s
                    }
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: modelData.state === UPowerDeviceState.Charging ? Colors.success
                        : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 1: Power Profiles ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        EmptyLabel {
            visible: !root.profileDaemonAvailable
            text: "power-profiles-daemon not available"
        }

        Repeater {
            // `visible` on a Repeater doesn't hide its delegates (they're
            // parented to the Column) — gate the model instead.
            model: root.profileDaemonAvailable ? root.powerProfiles : []

            delegate: PanelRow {
                width: parent.width
                height: root.rowHeight
                required property var modelData
                required property int index

                property bool isActive: BatteryModel.profileIndex === modelData.enumVal

                selected: root.inSection && index === root.selDevice
                panel: root
                itemIndex: index
                onClicked: if (!isActive) BatteryModel.setProfile(modelData.enumVal)

                Row {
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    ThemeText {
                        text: modelData.icon
                        color: isActive ? Colors.success : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        verticalAlignment: Text.AlignVCenter
                    }

                    ThemeText {
                        text: modelData.name
                        color: isActive ? Colors.success : Colors.foreground
                        font.bold: isActive
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                ThemeText {
                    text: isActive ? "Active" : ""
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.success
                    font.bold: true
                }
            }
        }
    }
}
