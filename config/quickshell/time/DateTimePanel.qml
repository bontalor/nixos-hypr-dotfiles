import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

FloatingWindow {
    id: root
    title: "Date & Time"
    color: "transparent"
    implicitWidth: 850
    implicitHeight: 450
    visible: false

    onClosed: visible = false

    property int selSection: 0
    property bool inSection: false
    property int selDevice: 0

    property var sections: [
        { name: "Date" },
        { name: "Time" },
        { name: "Calendar" }
    ]

    property var now: new Date()
    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    function currentModelLength() {
        if (selSection === 2) return 42
        return 0
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: now = new Date()
        onRunningChanged: {
            if (running) now = new Date()
        }
    }

    Rectangle {
        id: mainRect
        anchors.fill: parent
        color: "transparent"
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Tab:
                if (!inSection) {
                    inSection = true
                    selDevice = 0
                } else {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                }
                event.accepted = true; break
            case Qt.Key_Backtab:
                if (inSection) {
                    inSection = false
                }
                event.accepted = true; break
            case Qt.Key_J:
            case Qt.Key_Down:
                if (inSection) {
                    var maxD = currentModelLength() - 1
                    selDevice = Math.min(selDevice + 1, Math.max(0, maxD))
                } else {
                    selSection = Math.min(selSection + 1, sections.length - 1)
                }
                event.accepted = true; break
            case Qt.Key_K:
            case Qt.Key_Up:
                if (inSection) {
                    selDevice = Math.max(selDevice - 1, 0)
                } else {
                    selSection = Math.max(selSection - 1, 0)
                }
                event.accepted = true; break
            case Qt.Key_Escape:
                root.visible = false
                event.accepted = true; break
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Repeater {
                        model: sections

                        delegate: Rectangle {
                            width: parent.width
                            height: 30
                            color: selSection === index ? Qt.alpha(Colors.base01, 0.75) : "transparent"

                            Text {
                                text: modelData.name
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    right: parent.right; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                leftPadding: selSection === index && inSection ? 18 : 0
                            }

                            Text {
                                text: "\u25b6"
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                visible: selSection === index && inSection
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    selSection = index
                                    inSection = false
                                    mainRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.75
                height: parent.height
                color: Qt.alpha(Colors.base00, 0.75)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentHeight: contentCol.height
                    clip: true

                    function scrollToVisible(itemY, itemH) {
                        var viewH = flick.height
                        var maxY = Math.max(0, contentCol.height - viewH)
                        if (itemY < flick.contentY) {
                            flick.contentY = Math.max(0, itemY - 40)
                        } else if (itemY + itemH > flick.contentY + viewH) {
                            flick.contentY = Math.min(maxY, itemY + itemH - viewH + 10)
                        }
                    }

                    function scrollToSelection() {
                        var y, h
                        if (inSection && selSection === 2) {
                            y = 40 + Math.floor(selDevice / 7) * 36
                            h = 30
                        }
                        if (y !== undefined) flick.scrollToVisible(y, h)
                    }

                    Column {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            height: 30
                            color: Qt.alpha(Colors.base0d, 0.75)

                            Text {
                                text: sections[selSection]?.name ?? ""
                                anchors {
                                    left: parent.left; leftMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                color: Colors.foreground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: true
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 0

                            Item {
                                width: parent.width
                                height: 30 * 3

                                Column {
                                    anchors.fill: parent
                                    spacing: 10

                                    Text {
                                        text: dayNames[root.now.getDay()] + ", " + monthNames[root.now.getMonth()] + " " + root.now.getDate() + ", " + root.now.getFullYear()
                                        color: Colors.foreground
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        text: "Day of year: " + Math.floor((root.now - new Date(root.now.getFullYear(), 0, 0)) / 86400000)
                                        color: Qt.alpha(Colors.foreground, 0.75)
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                    Text {
                                        text: "Week: " + (function() {
                                            var d = new Date(root.now)
                                            d.setHours(0,0,0,0)
                                            d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7)
                                            var week1 = new Date(d.getFullYear(), 0, 4)
                                            return 1 + Math.round(((d - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
                                        })()
                                        color: Qt.alpha(Colors.foreground, 0.75)
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }

                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 10
                                visible: selSection === 1

                                Item {
                                    width: parent.width
                                    height: 30 * 3

                                    Column {
                                        anchors.fill: parent
                                        spacing: 10

                                        Text {
                                            text: ("  " + root.now.getHours()).slice(-2) + ":" + ("  " + root.now.getMinutes()).slice(-2) + ":" + ("  " + root.now.getSeconds()).slice(-2)
                                            color: Colors.foreground
                                            font.pixelSize: 24
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.bold: true
                                        }

                                        Text {
                                            text: "Timezone: " + (function() {
                                                var s = root.now.toString()
                                                return s.substring(s.indexOf("(") + 1, s.indexOf(")"))
                                            })()
                                            color: Qt.alpha(Colors.foreground, 0.75)
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        Text {
                                            text: "UTC: " + root.now.toUTCString()
                                            color: Qt.alpha(Colors.foreground, 0.75)
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 10
                            visible: selSection === 2

                            Item {
                                width: parent.width
                                height: 30

                                Row {
                                    anchors { left: parent.left; right: parent.right }
                                    spacing: 0

                                    Repeater {
                                        model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

                                        delegate: Text {
                                            width: parent.width / 7
                                            height: 30
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData
                                            color: Qt.alpha(Colors.foreground, 0.75)
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }
                                    }
                                }
                            }

                            Grid {
                                id: calendarGrid
                                width: parent.width
                                columns: 7
                                spacing: 0

                                property var firstDay: new Date(root.now.getFullYear(), root.now.getMonth(), 1)
                                property var startDay: new Date(firstDay)
                                property int startDayOfWeek: startDay.getDay()

                                Component.onCompleted: {
                                    startDay.setDate(startDay.getDate() - startDayOfWeek)
                                }

                                Repeater {
                                    model: 42

                                    delegate: Rectangle {
                                        width: calendarGrid.width / 7
                                        height: calendarGrid.width / 7
                                        color: {
                                            var d = new Date(calendarGrid.startDay)
                                            d.setDate(d.getDate() + index)
                                            var today = d.getDate() === root.now.getDate() && d.getMonth() === root.now.getMonth() && d.getFullYear() === root.now.getFullYear()
                                            var sel = inSection && selDevice === index
                                            if (sel) return Qt.alpha(Colors.base01, 0.75)
                                            if (today) return Qt.alpha(Colors.base0d, 0.75)
                                            return "transparent"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            property var cellDate: {
                                                var d = new Date(calendarGrid.startDay)
                                                d.setDate(d.getDate() + index)
                                                return d
                                            }
                                            text: cellDate.getDate()
                                            color: cellDate.getMonth() !== root.now.getMonth()
                                                ? Qt.alpha(Colors.foreground, 0.75)
                                                : Colors.foreground
                                            font.pixelSize: 16
                                            font.family: "JetBrainsMono Nerd Font"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                selSection = 2
                                                inSection = true
                                                selDevice = index
                                                mainRect.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
