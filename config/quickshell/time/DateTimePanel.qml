import "../theme"
import QtQuick
import Quickshell
import Quickshell.Io

Panel {
    id: root
    title: "Date & Time"
    sections: [
        { name: "Date" },
        { name: "Time" },
        { name: "Calendar" }
    ]

    autoScroll: false

    property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    property var now: clock.date

    property string timezoneString: {
        var s = root.now.toString()
        return s.substring(s.indexOf("(") + 1, s.indexOf(")"))
    }

    property int isoWeek: computeIsoWeek(root.now)

    function computeIsoWeek(d) {
        var date = new Date(d)
        date.setHours(0, 0, 0, 0)
        date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7)
        var week1 = new Date(date.getFullYear(), 0, 4)
        return 1 + Math.round(((date - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7)
    }

    currentModelLength: function() { return root.selSection === 2 ? 42 : 0 }

    onSelDeviceChanged: root.calendarScroll()
    onInSectionChanged: if (root.inSection) root.calendarScroll()

    function calendarScroll() {
        if (!root.inSection || root.selSection !== 2) return
        var y = root.headerHeight + root.colSpacing + Math.floor(root.selDevice / 7) * 36
        root.flick.scrollToVisible(y, 30)
    }

    // ---- Section 0: Date ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 0

        Item {
            width: parent.width
            height: 30 * 3 + 20

            Column {
                anchors.fill: parent
                spacing: 10

                Text {
                    text: root.dayNames[root.now.getDay()] + ", " + root.monthNames[root.now.getMonth()] + " " + root.now.getDate() + ", " + root.now.getFullYear()
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
                    text: "Week: " + root.isoWeek
                    color: Qt.alpha(Colors.foreground, 0.75)
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
        }
    }

    // ---- Section 1: Time ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 1

        Item {
            width: parent.width
            height: 30 * 3 + 20

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
                    text: "Timezone: " + root.timezoneString
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

    // ---- Section 2: Calendar ----
    Column {
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === 2

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
            property var startDay: {
                var d = new Date(firstDay)
                d.setDate(d.getDate() - d.getDay())
                return d
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
                        if (root.inSection && root.selDevice === index) return Qt.alpha(Colors.base01, 0.75)
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
                            root.selSection = 2
                            root.inSection = true
                            root.selDevice = index
                            root.forceFocus()
                        }
                    }
                }
            }
        }
    }
}