// Settings panel — user-facing shell preferences, persisted via
// PrefStore (shared statePath JSON, also read by the lockscreen
// instance). Every setting is a ConfigExpandItem whose profile rows are
// the allowed values, so keyboard navigation (Tab to expand, J/K,
// Enter) comes entirely from Panel's expandable-config mode.
//
// Add a new setting by appending to a group in `settingsGroups` (or
// adding a group — the sidebar dropdown follows) and declaring the pref
// on PrefStore's adapter; consumers bind to PrefStore directly.
//
// An option with `custom: true` renders as a "Custom..." row that turns
// into an inline TextInput (the WeatherPanel city flow): Enter commits
// the typed value to the pref, Escape/Shift+Tab cancels. The paired
// plain option (value: "") is the "use the default" reset.

pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import "../util"
import QtQuick
import Qt.labs.platform as Platform

Panel {
    id: root
    title: "Settings"

    // One "General" section whose sidebar dropdown lists the setting
    // groups; each group is a subsection (Panel renders `subs` as the
    // dropdown) and `settings` drives the content for that group.
    readonly property var settingsGroups: [
        { name: "Quickshell", settings: [
            { label: "Lowercase text", pref: "allLowercase",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] },
        { name: "Bar", settings: [
            { label: "Bar position", pref: "barPosition",
              options: [ { name: "Top", value: "top" }, { name: "Bottom", value: "bottom" } ] },
            { label: "Audio visualizer", pref: "visualizer",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] },
            { label: "Distro icon", pref: "distroIcon",
              options: [ { name: "Auto (detect distro)", value: "" },
                         { name: "Browse…", custom: true, picker: "file",
                           filters: ["Image files (*.png *.svg *.xpm *.jpg *.ico)", "All files (*)"] } ] }
        ] },
        { name: "Wallpaper", settings: [
            { label: "Wallpaper directory", pref: "wallpaperDir",
              options: [ { name: "Default (~/walls)", value: "" },
                         { name: "Browse…", custom: true, picker: "directory" } ] }
        ] },
        { name: "Weather", settings: [
            { label: "Temperature unit", pref: "weatherUnit",
              options: [ { name: "Fahrenheit", value: "F" }, { name: "Celsius", value: "C" } ] },
            { label: "City", pref: "weatherCity",
              options: [ { name: "Auto (IP)", value: "" },
                         { name: "Custom...", custom: true } ] }
        ] },
        { name: "Date & Time", settings: [
            { label: "Clock format", pref: "timeFormat",
              options: [ { name: "12-hour", value: "12h" }, { name: "24-hour", value: "24h" } ] },
            { label: "Bar clock seconds", pref: "timeSeconds",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] },
            { label: "Week starts on", pref: "weekStart",
              options: [ { name: "Sunday", value: "sunday" }, { name: "Monday", value: "monday" } ] }
        ] },
        { name: "Notifications", settings: [
            { label: "Notification popups", pref: "notifPopups",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] },
            { label: "Popup duration", pref: "notifExpireSec",
              options: [ { name: "3 seconds", value: 3 }, { name: "5 seconds", value: 5 },
                         { name: "10 seconds", value: 10 } ] }
        ] },
        { name: "Clipboard", settings: [
            // Stops both wl-paste watchers; existing history is kept
            // (Clear All in the clipboard panel wipes it).
            { label: "Clipboard history", pref: "clipboardHistory",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] },
        { name: "Battery", settings: [
            { label: "Low battery warning", pref: "batteryWarnLevel",
              options: [ { name: "15%", value: 15 }, { name: "20%", value: 20 },
                         { name: "25%", value: 25 }, { name: "30%", value: 30 } ] }
        ] },
        { name: "Lock Screen", settings: [
            { label: "Fingerprint unlock", pref: "fingerprintUnlock",
              options: [ { name: "On", value: true }, { name: "Off", value: false } ] }
        ] },
        { name: "System", settings: [
            // Used wherever the shell opens a terminal program (nmtui);
            // the configured terminal must accept `-e <command>`.
            { label: "Terminal", pref: "terminal",
              options: [ { name: "Default (foot)", value: "" },
                         { name: "Custom...", custom: true } ] }
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
            // A custom option is "current" whenever the pref holds any
            // non-default (non-empty) value.
            if (s.options[i].custom ? PrefStore[s.pref] !== ""
                                    : s.options[i].value === PrefStore[s.pref]) return i
        }
        return 0
    }
    onConfigActivated: root.applyOption(root.selConfigItem, root.selConfigProfile)

    // Inline-edit state for `custom: true` options: the setting index
    // being edited (-1 = none) and the text being typed. Collapsing the
    // dropdown (section switch, Escape, activation) always ends the edit,
    // like WeatherPanel's city flow.
    property int editingItem: -1
    property string editText: ""
    onConfigExpandedChanged: if (!configExpanded) root.editingItem = -1

    function deferredFocus() { Qt.callLater(root.forceFocus) }

    function commitEdit(itemIdx, text) {
        var s = root.currentSettings[itemIdx]
        if (s) PrefStore[s.pref] = text.trim()   // "" resets to the default
        root.editingItem = -1
        root.configExpanded = false
        root.deferredFocus()
    }

    // Escape / Shift+Tab back out of an inline edit before the default
    // handler collapses anything (same pre-emption as WeatherPanel).
    onKeyPressed: function(event) {
        if (root.editingItem < 0) return
        if (event.key === Qt.Key_Escape
            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
            || event.key === Qt.Key_Backtab) {
            root.editingItem = -1
            root.deferredFocus()
            event.accepted = true
        }
    }

    // Native file/directory picker for `picker:` options (distroIcon,
    // wallpaperDir). Qt.labs.platform routes to the XDG portal on Wayland.
    // _pickerPref tracks which pref to write after the dialog closes.
    property string _pickerPref: ""

    Platform.FileDialog {
        id: settingsFileDlg
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            if (root._pickerPref !== "") {
                var s = settingsFileDlg.file.toString()
                PrefStore[root._pickerPref] = s.startsWith("file://") ? s.slice(7) : s
            }
            root._pickerPref = ""
        }
        onRejected: root._pickerPref = ""
    }

    Platform.FolderDialog {
        id: settingsFolderDlg
        onAccepted: {
            if (root._pickerPref !== "") {
                var s = settingsFolderDlg.folder.toString()
                PrefStore[root._pickerPref] = s.startsWith("file://") ? s.slice(7) : s
            }
            root._pickerPref = ""
        }
        onRejected: root._pickerPref = ""
    }

    function optionName(setting, value) {
        for (var i = 0; i < setting.options.length; i++) {
            if (setting.options[i].value === value) return setting.options[i].name
        }
        return String(value)
    }

    function applyOption(itemIdx, optIdx) {
        var s = root.currentSettings[itemIdx]
        if (!s || optIdx < 0 || optIdx >= s.options.length) return
        var opt = s.options[optIdx]
        if (opt.picker) {
            // Open the native dialog; pref is written in the dialog's onAccepted.
            root._pickerPref = s.pref
            root.configExpanded = false
            if (opt.picker === "directory") {
                settingsFolderDlg.title = "Choose " + s.label
                settingsFolderDlg.open()
            } else {
                settingsFileDlg.title = "Choose " + s.label
                settingsFileDlg.nameFilters = opt.filters || ["All files (*)"]
                settingsFileDlg.open()
            }
            return
        }
        if (opt.custom) {
            // TextInput inline-edit for typed custom values (weather city, terminal, …).
            root.editingItem = itemIdx
            root.editText = PrefStore[s.pref]
            return
        }
        PrefStore[s.pref] = opt.value
        root.configExpanded = false
    }

    Column {
        width: parent.width
        spacing: root.colSpacing

        Repeater {
            model: root.currentSettings

            delegate: ConfigExpandItem {
                id: settingItem
                required property var modelData
                required property int index
                // The inner Repeater's modelData shadows this one.
                property var setting: settingItem.modelData

                label: settingItem.modelData.label
                // Reading PrefStore[pref] inside the binding registers a
                // dependency on that property, so the shown value tracks
                // changes live (including edits from another instance).
                sublabel: root.optionName(settingItem.modelData, PrefStore[settingItem.modelData.pref])
                isSelected: root.inSection && index === root.selConfigItem
                isExpanded: root.configExpanded && index === root.selConfigItem
                profileCount: settingItem.modelData.options.length
                panel: root
                itemIndex: index

                Repeater {
                    model: settingItem.isExpanded ? settingItem.setting.options : []

                    delegate: ConfigProfileRow {
                        id: optionRow
                        required property var modelData
                        required property int index
                        // While editing a typed custom value, the label yields
                        // to the inline TextInput. Picker-type options (`picker`
                        // property set) open the OS portal instead — no TextInput.
                        readonly property bool editing: optionRow.modelData.custom === true
                            && !optionRow.modelData.picker
                            && root.editingItem === settingItem.itemIndex
                        label: editing ? "" : optionRow.modelData.name
                        isSelected: !editing && index === root.selConfigProfile
                        onClicked: {
                            if (root.inSection && !optionRow.editing) {
                                root.selConfigProfile = index
                                root.applyOption(settingItem.itemIndex, index)
                            }
                        }

                        TextInput {
                            visible: optionRow.editing
                            anchors {
                                left: parent.left; leftMargin: 3 * Theme.margin
                                right: parent.right; rightMargin: Theme.margin
                                verticalCenter: parent.verticalCenter
                            }
                            color: Colors.foreground
                            font.pixelSize: Theme.fontPixelSize
                            font.family: Theme.fontFamily
                            text: root.editText
                            focus: optionRow.editing
                            onAccepted: root.commitEdit(settingItem.itemIndex, text)
                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    root.editingItem = -1
                                    root.deferredFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
