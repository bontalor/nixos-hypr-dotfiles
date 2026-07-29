pragma ComponentBehavior: Bound
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

    // --- Per-row dropdown state (Battery + Power Profiles sections) ---
    // Every clickable row in this panel opens a dropdown with its
    // available actions: Battery rows show "Track this device", Power
    // Profile rows show "Activate". No row direct-activates on click
    // — every option goes through the same header-click → action-list
    // flow. State + close/toggle/trigger helpers + keyboard nav all
    // live on the shared DropdownState; the panel supplies the
    // rowActions(idx) hook (per-section action list) and the
    // triggerAction(idx, actIdx) hook (per-section perform).
    DropdownState {
        id: dropdown
        selectRow: function(idx) { root.selectRow(idx) }
        rowActions: function(idx) { return root.currentRowActions(idx) }
        triggerAction: function(idx, actIdx) {
            var acts = root.currentRowActions(idx)
            var act = acts[actIdx]
            if (!act) return
            if (act.action === "track") {
                var dev = BatteryModel.batteryDevices[idx]
                if (dev) BatteryModel.selectDevice(dev.nativePath)
            } else if (act.action === "activate") {
                var entry = root.powerProfiles[idx]
                if (entry) BatteryModel.setProfile(entry.enumVal)
            }
        }
    }

    // Aliases keep the existing `root.expandedRowIdx` / `root.selRowAction`
    // delegate bindings working without further wiring.
    property int expandedRowIdx: dropdown.expandedRowIdx
    property int selRowAction: dropdown.selRowAction
    function closeRowDropdown() { dropdown.close() }
    function toggleRowDropdown(idx) { dropdown.toggle(idx) }
    function triggerRowAction(idx, actIdx) { dropdown.trigger(idx, actIdx) }

    function batteryActions(dev) {
        if (!dev) return []
        var isActive = BatteryModel.activeDevice === dev
        return [{ name: isActive ? "Tracking (active)" : "Track this device",
                  action: "track" }]
    }
    function profileActions(entry) {
        if (!entry) return []
        var isActive = BatteryModel.profileIndex === entry.enumVal
        return [{ name: isActive ? "Re-apply" : "Activate",
                  action: "activate" }]
    }
    function currentRowActions(idx) {
        switch (root.selSection) {
        case 0: return root.batteryActions(BatteryModel.batteryDevices[idx])
        case 1: return root.profileActions(root.powerProfiles[idx])
        default: return []
        }
    }

    currentModelLength: function() {
        switch (root.selSection) {
        case 0: return BatteryModel.batteryDevices.length
        case 1: return root.powerProfiles.length
        default: return 0
        }
    }

    onDeviceActivated: function(idx) {
        // Dropdown-driven; onKeyPressed delegates to DropdownState which
        // opens / closes / triggers as appropriate. Kept as a no-op to
        // satisfy PanelNav's contract.
    }

    onKeyPressed: function(event) {
        if (root.inSection && (root.selSection === 0 || root.selSection === 1)) {
            if (dropdown.handleKey(event, root.selDevice)) return
        }
    }

    onVisibleChanged: if (!visible) root.closeRowDropdown()
    onSelSectionChanged: root.closeRowDropdown()

    // Variable-height scroll: open dropdowns push the row past rowHeight.
    onSelRowActionChanged: Qt.callLater(root.scrollToSelection)
    onExpandedRowIdxChanged: Qt.callLater(root.scrollToSelection)

    function scrollToSelection() {
        if (!root.inSection) return
        // Sections 0 (Battery) and 1 (Power Profiles) both use
        // variable-height DropdownRow delegates — read the real geometry
        // from the Repeater so open dropdowns scroll correctly.
        var repeater = root.selSection === 0 ? batRepeater : profileRepeater
        var columnY = root.selSection === 0 ? batColumn.y : profileColumn.y
        var item = repeater.itemAt(root.selDevice)
        if (!item) return
        root.scrollToVisible(columnY + item.y, item.height)
        if (root.expandedRowIdx === root.selDevice && root.selRowAction >= 0) {
            var actY = columnY + item.y + root.rowHeight
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
                id: batRow
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

                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)

                ThemeText {
                    id: devName
                    text: BatteryModel.deviceName(batRow.modelData)
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: batRow.isActive ? Colors.success : Colors.foreground
                    font.bold: batRow.isActive
                }

                ThemeText {
                    text: batRow.pct + "%"
                    anchors { left: devName.right; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: batRow.pct <= BatteryModel.batteryCritical ? Colors.critical
                        : batRow.pct <= BatteryModel.batteryWarning ? Colors.warning
                        : Colors.foreground
                    font.bold: true
                }

                ThemeText {
                    text: {
                        var s = BatteryModel.stateText(batRow.modelData)
                        s = s ? s.charAt(0).toUpperCase() + s.slice(1) : ""
                        var t = FormatUtil.fmtDuration(
                            batRow.modelData.state === UPowerDeviceState.Charging
                                ? batRow.modelData.timeToFull : batRow.modelData.timeToEmpty)
                        return t ? s + " · " + t : s
                    }
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: batRow.modelData.state === UPowerDeviceState.Charging ? Colors.success
                        : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                }
            }
        }
    }

    // ---- Section 1: Power Profiles ----
    Column {
        id: profileColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        EmptyLabel {
            visible: !root.profileDaemonAvailable
            text: "power-profiles-daemon not available"
        }

        Repeater {
            id: profileRepeater
            // `visible` on a Repeater doesn't hide its delegates (they're
            // parented to the Column) — gate the model instead.
            model: root.profileDaemonAvailable ? root.powerProfiles : []

            delegate: DropdownRow {
                id: profRow
                width: parent.width
                rowHeight: root.rowHeight
                required property var modelData
                required property int index

                property bool isActive: BatteryModel.profileIndex === modelData.enumVal

                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.profileActions(modelData)

                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)

                Row {
                    anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    spacing: Theme.margin

                    ThemeText {
                        text: profRow.modelData.icon
                        color: profRow.isActive ? Colors.success : Qt.alpha(Colors.foreground, Theme.alphaBackground)
                        verticalAlignment: Text.AlignVCenter
                    }

                    ThemeText {
                        text: profRow.modelData.name
                        color: profRow.isActive ? Colors.success : Colors.foreground
                        font.bold: profRow.isActive
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                ThemeText {
                    text: profRow.isActive ? "Active" : ""
                    anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
                    color: Colors.success
                    font.bold: true
                }
            }
        }
    }
}
