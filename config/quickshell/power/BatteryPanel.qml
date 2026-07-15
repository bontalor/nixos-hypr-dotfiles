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

    // autoScroll stays true (default) — Panel.qml's onSelDeviceChanged
    // etc. route to scrollToSelection, which we override below to read
    // the real delegate height for the Battery section (open dropdowns
    // push the row past rowHeight). The Power Profiles section uses
    // fixed-stride rows and falls through to the base math.

    property var powerProfiles: BatteryModel.profiles
    property bool profileDaemonAvailable: BatteryModel.profileIndex >= 0

    // --- Per-row dropdown state (Battery section) ---
    // Battery devices get a dropdown so the panel stops immediately
    // re-selecting on Enter; "Track" swaps which device the widget
    // follows. Power Profiles keeps its direct-click activation (the
    // whole row IS the action — there's nothing else to do with a
    // profile besides switching to it), matching the rest of the
    // shell's convention that one-action rows stay direct.
    property int expandedRowIdx: -1
    property int selRowAction: 0

    function closeRowDropdown() { root.expandedRowIdx = -1; root.selRowAction = 0 }
    function toggleRowDropdown(idx) {
        if (root.expandedRowIdx === idx) root.closeRowDropdown()
        else { root.expandedRowIdx = idx; root.selRowAction = 0 }
    }
    function batteryActions(dev) {
        if (!dev) return []
        var isActive = BatteryModel.activeDevice === dev
        return [{ name: isActive ? "Tracking (active)" : "Track this device",
                  action: "track" }]
    }
    function triggerRowAction(idx, actIdx) {
        var dev = BatteryModel.batteryDevices[idx]
        var acts = root.batteryActions(dev)
        var act = acts[actIdx]
        if (act && act.action === "track" && dev)
            BatteryModel.selectDevice(dev.nativePath)
        root.closeRowDropdown()
    }

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return BatteryModel.batteryDevices.length
        case 1: return root.powerProfiles.length
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        // Battery section is dropdown-driven (see onKeyPressed); Power
        // Profiles keeps direct activation — switching is the only
        // thing a profile row does.
        if (root.selSection === 1) {
            var entry = root.powerProfiles[idx]
            if (entry && BatteryModel.profileIndex !== entry.enumVal)
                BatteryModel.setProfile(entry.enumVal)
        }
    }

    onKeyPressed: function(event) {
        if (root.inSection && root.selSection === 0) {
            var open = root.expandedRowIdx === root.selDevice
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Tab:
                if (event.modifiers & Qt.ShiftModifier) {
                    if (open) { root.closeRowDropdown(); event.accepted = true; return }
                    return  // PanelNav climbs out
                }
                if (open) root.triggerRowAction(root.selDevice, root.selRowAction)
                else root.toggleRowDropdown(root.selDevice)
                event.accepted = true; return
            case Qt.Key_Backtab:
                if (open) { root.closeRowDropdown(); event.accepted = true; return }
                return
            case Qt.Key_Escape:
                if (open) { root.closeRowDropdown(); event.accepted = true; return }
                return
            case Qt.Key_J:
            case Qt.Key_Down:
                if (open) {
                    root.selRowAction = Scroll.step(
                        root.selRowAction, 1,
                        root.batteryActions(BatteryModel.batteryDevices[root.selDevice]).length)
                    event.accepted = true; return
                }
                return
            case Qt.Key_K:
            case Qt.Key_Up:
                if (open) {
                    root.selRowAction = Scroll.step(
                        root.selRowAction, -1,
                        root.batteryActions(BatteryModel.batteryDevices[root.selDevice]).length)
                    event.accepted = true; return
                }
                return
            }
        }
    }

    onVisibleChanged: if (!visible) root.closeRowDropdown()
    onSelSectionChanged: root.closeRowDropdown()

    // Variable-height scroll: open dropdowns push the row past rowHeight.
    onSelRowActionChanged: Qt.callLater(root.scrollToSelection)
    onExpandedRowIdxChanged: Qt.callLater(root.scrollToSelection)

    function scrollToSelection() {
        if (!root.inSection) return
        // Power Profiles: fixed-stride rows — use the base math.
        if (root.selSection !== 0) {
            root.scrollToVisible(
                root.headerHeight + root.colSpacing
                + root.selDevice * (root.rowHeight + root.colSpacing),
                root.rowHeight)
            return
        }
        // Battery: read real delegate height (dropdown adds height).
        var item = batRepeater.itemAt(root.selDevice)
        if (!item) return
        root.scrollToVisible(batColumn.y + item.y, item.height)
        if (root.expandedRowIdx === root.selDevice && root.selRowAction >= 0) {
            var actY = batColumn.y + item.y + root.rowHeight
                      + root.selRowAction * Theme.searchRowHeight
            root.scrollToVisible(actY, Theme.searchRowHeight)
        }
    }

    // ---- Section 0: Battery list ----
    Column {
        id: batColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        EmptyLabel {
            visible: BatteryModel.batteryDevices.length === 0
            text: "No batteries detected"
        }

        Repeater {
            id: batRepeater
            model: BatteryModel.batteryDevices

            delegate: DropdownRow {
                width: parent.width
                rowHeight: root.rowHeight
                required property var modelData
                required property int index

                property bool isActive: BatteryModel.activeDevice === modelData
                property int pct: Math.round(modelData.percentage * 100)

                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.batteryActions(modelData)

                onToggled: {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.toggleRowDropdown(index)
                }
                onActionTriggered: (idx) => {
                    if (!root.inSection) { root.inSection = true; root.selDevice = index }
                    root.selRowAction = idx
                    root.triggerRowAction(index, idx)
                }

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
