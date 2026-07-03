// Settings panel — user-facing shell preferences, persisted via
// PrefStore (shared statePath JSON, also read by the lockscreen
// instance). Every setting is a ConfigExpandItem whose profile rows are
// the allowed values, so keyboard navigation (Tab to expand, J/K,
// Enter) comes entirely from Panel's expandable-config mode.
//
// Add a new setting by appending to a group in `settingsGroups` (or
// adding a group — the sidebar dropdown follows) and declaring the pref
// on PrefStore's adapter; consumers bind to PrefStore directly.

import "../theme"
import "../util"
import QtQuick

Panel {
    id: root
    title: "Settings"

    // One "General" section whose sidebar dropdown lists the setting
    // groups; each group is a subsection (Panel renders `subs` as the
    // dropdown) and `settings` drives the content for that group.
    readonly property var settingsGroups: [
        { name: "Bar", settings: [
            { label: "Bar position", pref: "barPosition",
              options: [ { name: "Top", value: "top" }, { name: "Bottom", value: "bottom" } ] },
            { label: "Audio visualizer", pref: "visualizer",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] },
        { name: "Date & Time", settings: [
            { label: "Clock format", pref: "timeFormat",
              options: [ { name: "12-hour", value: "12h" }, { name: "24-hour", value: "24h" } ] }
        ] },
        { name: "Notifications", settings: [
            { label: "Notification popups", pref: "notifPopups",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] },
        { name: "Lock Screen", settings: [
            { label: "Fingerprint unlock", pref: "fingerprintUnlock",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] }
    ]

    sections: [{ name: "General", subs: root.settingsGroups }]

    // Settings of the selected subsection; empty until one is chosen
    // (the General dropdown starts collapsed with nothing selected).
    readonly property var currentSettings: root.selSub >= 0
        ? root.settingsGroups[root.selSub].settings : []

    expandSection: 0
    configItemCount: function() { return root.currentSettings.length }
    configProfileCount: function() {
        var s = root.currentSettings[root.selConfigItem]
        return s ? s.options.length : 0
    }
    configCurrentProfile: function() {
        var s = root.currentSettings[root.selConfigItem]
        if (!s) return 0
        for (var i = 0; i < s.options.length; i++) {
            if (s.options[i].value === PrefStore[s.pref]) return i
        }
        return 0
    }
    onConfigActivated: root.applyOption(root.selConfigItem, root.selConfigProfile)

    function optionName(setting, value) {
        for (var i = 0; i < setting.options.length; i++) {
            if (setting.options[i].value === value) return setting.options[i].name
        }
        return String(value)
    }

    function applyOption(itemIdx, optIdx) {
        var s = root.currentSettings[itemIdx]
        if (!s || optIdx < 0 || optIdx >= s.options.length) return
        PrefStore[s.pref] = s.options[optIdx].value
        root.configExpanded = false
    }

    Column {
        width: parent.width
        spacing: root.colSpacing

        Repeater {
            model: root.currentSettings

            delegate: ConfigExpandItem {
                id: settingItem
                // The inner Repeater's modelData shadows this one.
                property var setting: modelData

                label: modelData.label
                // Reading PrefStore[pref] inside the binding registers a
                // dependency on that property, so the shown value tracks
                // changes live (including edits from another instance).
                sublabel: root.optionName(modelData, PrefStore[modelData.pref])
                isSelected: root.inSection && index === root.selConfigItem
                isExpanded: root.configExpanded && index === root.selConfigItem
                profileCount: modelData.options.length
                panel: root
                itemIndex: index

                Repeater {
                    model: settingItem.isExpanded ? settingItem.setting.options : []

                    delegate: ConfigProfileRow {
                        label: modelData.name
                        isSelected: index === root.selConfigProfile
                        onClicked: if (root.inSection) root.applyOption(settingItem.itemIndex, index)
                    }
                }
            }
        }
    }
}
