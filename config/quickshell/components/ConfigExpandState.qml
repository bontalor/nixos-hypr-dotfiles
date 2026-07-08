// Encapsulates the expandable-config section state shared by VolumePanel,
// NetworkPanel, and SettingsPanel. PanelNav composes this; Panel.qml
// reaches config properties through the PanelNav alias chain.
//
// Properties:
//   expandSection       — section index with expandable config, -1 = none
//   configExpanded      — whether the profile sub-list is open
//   selConfigItem       — selected config item index within the section
//   selConfigProfile    — selected profile index within the item
//   configItemCount     — function() -> int  (number of items in this section)
//   configProfileCount  — function() -> int  (profiles for the selected item)
//   configCurrentProfile — function() -> int  (auto-selected on expand)

import QtQuick

QtObject {
    id: root

    property int expandSection: -1
    property bool configExpanded: false
    property int selConfigItem: 0
    property int selConfigProfile: 0
    property var configItemCount: function() { return 0 }
    property var configProfileCount: function() { return 0 }
    property var configCurrentProfile: function() { return 0 }

    function toggleConfigItem(idx) {
        if (root.configExpanded && idx === root.selConfigItem) {
            root.configExpanded = false
        } else {
            root.selConfigItem = idx
            root.configExpanded = true
            root.selConfigProfile = Math.max(0, root.configCurrentProfile())
        }
    }

    function reset() {
        root.configExpanded = false
        root.selConfigItem = 0
        root.selConfigProfile = 0
    }
}
