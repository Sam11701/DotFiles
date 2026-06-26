import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root

    property var today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int selectedDay: today.getDate()
    property int selectedMonth: today.getMonth()
    property int selectedYear: today.getFullYear()

    property string weatherLocation: ""
    property var hourlyWeather: []

    signal closeRequested()

    readonly property var monthNames: ["January","February","March","April","May","June",
                                       "July","August","September","October","November","December"]
    readonly property var dayNames: ["S","M","T","W","T","F","S"]

    property var cells: {
        var y = root.viewYear
        var m = root.viewMonth
        var first = new Date(y, m, 1).getDay()
        var days = new Date(y, m + 1, 0).getDate()
        var prevDays = new Date(y, m, 0).getDate()
        var arr = []
        for (var i = first - 1; i >= 0; i--)
            arr.push({ day: prevDays - i, inMonth: false, month: m === 0 ? 11 : m - 1, year: m === 0 ? y - 1 : y })
        for (var d = 1; d <= days; d++)
            arr.push({ day: d, inMonth: true, month: m, year: y })
        var n = 1
        while (arr.length < 42)
            arr.push({ day: n++, inMonth: false, month: m === 11 ? 0 : m + 1, year: m === 11 ? y + 1 : y })
        return arr
    }

    function isoWeek(year, month, day) {
        var d = new Date(year, month, day)
        d.setHours(0, 0, 0, 0)
        d.setDate(d.getDate() + 3 - (d.getDay() + 6) % 7)
        var w1 = new Date(d.getFullYear(), 0, 4)
        return 1 + Math.round(((d - w1) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7)
    }

    Process {
        id: weatherProc
        running: true
        command: ["python3", "-c",
            "import urllib.request,json\n" +
            "try:\n" +
            " d=json.loads(urllib.request.urlopen('http://wttr.in/?format=j1',timeout=5).read())\n" +
            " loc=d['nearest_area'][0]['areaName'][0]['value']\n" +
            " h=d['weather'][0]['hourly']\n" +
            " print(loc+'|'+'|'.join(x['time'][:2]+':00,'+x['weatherDesc'][0]['value'][:14]+','+x['tempC'] for x in h[:5]))\n" +
            "except:print('?')"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "?") return
                var parts = line.trim().split("|")
                root.weatherLocation = parts[0] || ""
                var hw = []
                for (var i = 1; i < parts.length; i++) {
                    var p = parts[i].split(",")
                    if (p.length >= 3) hw.push({ time: p[0], desc: p[1], temp: p[2] + "°" })
                }
                root.hourlyWeather = hw
            }
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        onTriggered: { weatherProc.running = false; weatherProc.running = true }
    }

    width: 460
    implicitHeight: mainCol.implicitHeight + 40
    color: "#28ffffff"
    radius: 12

    // Glass rim border
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: parent.radius
        border.width: 1
        border.color: "#55ffffff"
        z: 10
    }

    // Top specular highlight — simulates light hitting the curved glass surface
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height * 0.45
        radius: parent.radius
        z: 9
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#30ffffff" }
            GradientStop { position: 1.0; color: "#00ffffff" }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 16
        spacing: 10

        // Header (not inset — sits flush at top)
        ColumnLayout {
            spacing: 2
            Layout.topMargin: 4

            Text {
                text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "dddd")
                color: "#969896"
                font.pixelSize: 14
                font.family: "Overpass Mono"
            }
            Text {
                text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "MMMM d yyyy")
                color: "#c5c8c6"
                font.pixelSize: 24
                font.bold: true
                font.family: "Overpass Mono"
            }
        }

        // ── Inset panel: calendar grid ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: calGrid.implicitHeight + 20
            color: "#2a000000"
            radius: 8

            ColumnLayout {
                id: calGrid
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 10
                spacing: 6

                // Month navigation
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "<"
                        color: "#969896"
                        font.pixelSize: 13
                        font.family: "Overpass Mono"
                        rightPadding: 6
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- }
                                else root.viewMonth--
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.monthNames[root.viewMonth] + "  " + root.viewYear
                        color: "#c5c8c6"
                        font.pixelSize: 12
                        font.family: "Overpass Mono"
                    }
                    Text {
                        text: ">"
                        color: "#969896"
                        font.pixelSize: 13
                        font.family: "Overpass Mono"
                        leftPadding: 6
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ }
                                else root.viewMonth++
                            }
                        }
                    }
                }

                // Day headers
                Row {
                    Layout.fillWidth: true
                    readonly property real cellW: (root.width - 32 - 52) / 7

                    Item { width: 28; height: 14 }

                    Repeater {
                        model: root.dayNames
                        Text {
                            width: parent.cellW
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: "#707880"
                            font.pixelSize: 11
                            font.family: "Overpass Mono"
                        }
                    }
                }

                // Calendar rows
                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: 6

                        Row {
                            id: weekRow
                            required property int index
                            readonly property int rowIdx: index
                            readonly property real cellW: (root.width - 32 - 52) / 7
                            readonly property var firstCell: root.cells[rowIdx * 7]
                            readonly property int weekNum: root.isoWeek(firstCell.year, firstCell.month, firstCell.day)

                            Text {
                                width: 28
                                height: 30
                                verticalAlignment: Text.AlignVCenter
                                text: weekRow.weekNum
                                color: "#707880"
                                font.pixelSize: 10
                                font.family: "Overpass Mono"
                            }

                            Repeater {
                                model: 7

                                Rectangle {
                                    required property int index
                                    readonly property var cell: root.cells[weekRow.rowIdx * 7 + index]
                                    readonly property bool inMonth: cell.inMonth
                                    readonly property int cellDay: cell.day
                                    readonly property bool isToday: inMonth
                                        && cellDay === root.today.getDate()
                                        && root.viewMonth === root.today.getMonth()
                                        && root.viewYear === root.today.getFullYear()
                                    readonly property bool isSelected: inMonth
                                        && cellDay === root.selectedDay
                                        && root.viewMonth === root.selectedMonth
                                        && root.viewYear === root.selectedYear

                                    width: weekRow.cellW
                                    height: 30
                                    radius: height / 2
                                    color: isToday ? "#cc6666" : isSelected ? "#3a000000" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.cellDay < 10 ? "0" + parent.cellDay : "" + parent.cellDay
                                        color: parent.isToday ? "#1d1f21"
                                             : parent.inMonth ? "#c5c8c6"
                                             : "#3d4147"
                                        font.pixelSize: 11
                                        font.family: "Overpass Mono"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (parent.inMonth) {
                                                root.selectedDay = parent.cellDay
                                                root.selectedMonth = root.viewMonth
                                                root.selectedYear = root.viewYear
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

        // ── Inset panel: events ─────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: eventsCol.implicitHeight + 20
            color: "#2a000000"
            radius: 8

            ColumnLayout {
                id: eventsCol
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 12
                spacing: 3

                Text {
                    text: Qt.formatDate(new Date(root.selectedYear, root.selectedMonth, root.selectedDay), "MMMM d")
                    color: "#c5c8c6"
                    font.pixelSize: 13
                    font.family: "Overpass Mono"
                }
                Text {
                    text: "No Events"
                    color: "#707880"
                    font.pixelSize: 11
                    font.family: "Overpass Mono"
                    font.italic: true
                }
            }
        }

        // ── Inset panel: weather ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: weatherCol.implicitHeight + 20
            color: "#2a000000"
            radius: 8

            ColumnLayout {
                id: weatherCol
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Weather"
                        color: "#c5c8c6"
                        font.pixelSize: 13
                        font.family: "Overpass Mono"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.weatherLocation || "..."
                        color: "#707880"
                        font.pixelSize: 11
                        font.family: "Overpass Mono"
                    }
                }

                Row {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.hourlyWeather

                        Column {
                            required property var modelData
                            width: (root.width - 32) / 5
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.time
                                color: "#707880"
                                font.pixelSize: 10
                                font.family: "Overpass Mono"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.desc.length > 8 ? modelData.desc.substring(0, 8) + "…" : modelData.desc
                                color: "#969896"
                                font.pixelSize: 10
                                font.family: "Overpass Mono"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.temp
                                color: "#c5c8c6"
                                font.pixelSize: 11
                                font.family: "Overpass Mono"
                            }
                        }
                    }

                    Text {
                        visible: root.hourlyWeather.length === 0
                        text: "Loading weather..."
                        color: "#707880"
                        font.pixelSize: 10
                        font.family: "Overpass Mono"
                        font.italic: true
                    }
                }
            }
        }
    }
}
