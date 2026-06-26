import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire

Rectangle {
    id: sidebar

    // External data - bound from shell.qml
    property var  clockNow: new Date()
    property int  cpuPct:   0
    property int  gpuPct:   0
    property int  memPct:   0

    // Page state
    property int  currentPage: 0

    // ── Aphelion palette ────────────────────────────────────────────────────
    readonly property color c_bg:  "#101319"
    readonly property color c_fg:  "#f4f3ee"
    readonly property color c_s0:  "#171b24"
    readonly property color c_dim: "#3A435A"
    readonly property color c_x1:  "#E34F4F"
    readonly property color c_x2:  "#69bfce"
    readonly property color c_x3:  "#e37e4f"
    readonly property color c_x4:  "#5679E3"
    readonly property color c_x5:  "#956dca"
    readonly property color c_x6:  "#5599E2"
    readonly property color c_x9:  "#DE2B2B"
    readonly property color c_x12: "#3E66E0"
    readonly property color c_x13: "#885AC4"

    // Day display (Mon-indexed: 0=Mon … 6=Sun)
    readonly property var dayLetters: ["M","T","W","T","F","S","S"]
    readonly property var dayColors:  [c_x1, c_x3, c_x2, c_x6, c_x4, c_x5, c_x1]

    readonly property var monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property string ff: "Overpass Mono"

    // ── Live data ────────────────────────────────────────────────────────────
    property string wxTemp: "..."
    property string wxDesc: "..."

    property string mediaStatus: "Stopped"
    property string mediaTitle:  "Nothing playing"
    property string mediaArtist: ""
    property string mediaArt:    ""
    property real   mediaPct:    0

    property int    diskPct:  0

    // Volume via Pipewire singleton (tracked in shell.qml)
    readonly property real volPct: {
        var s = Pipewire.defaultAudioSink
        return (s && s.audio) ? Math.round(s.audio.volume * 100) : 0
    }

    // ── Calendar state ───────────────────────────────────────────────────────
    property int calYear:  clockNow.getFullYear()
    property int calMonth: clockNow.getMonth()

    readonly property var calCells: {
        var y = calYear, m = calMonth
        var jsFirst = new Date(y, m, 1).getDay()
        var monFirst = jsFirst === 0 ? 6 : jsFirst - 1
        var days = new Date(y, m + 1, 0).getDate()
        var prev = new Date(y, m, 0).getDate()
        var arr = []
        for (var i = monFirst - 1; i >= 0; i--)
            arr.push({ day: prev - i, inMonth: false })
        for (var d = 1; d <= days; d++)
            arr.push({ day: d, inMonth: true })
        var n = 1
        while (arr.length < 42) arr.push({ day: n++, inMonth: false })
        return arr
    }

    // ── Processes ────────────────────────────────────────────────────────────
    Process {
        id: wxProc
        running: true
        command: ["bash", "-c", "curl -sf --max-time 5 'wttr.in/?format=%t+%C' 2>/dev/null || echo '-- --'"]
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.trim().split(" ")
                sidebar.wxTemp = p[0] || "--"
                sidebar.wxDesc = p.slice(1).join(" ") || "--"
            }
        }
    }
    Timer {
        interval: 1800000; running: true; repeat: true
        onTriggered: { wxProc.running = false; wxProc.running = true }
    }

    Process {
        id: diskProc
        running: true
        command: ["bash", "-c", "df / --output=pcent | tail -1 | tr -d ' %'"]
        stdout: SplitParser {
            onRead: function(line) { sidebar.diskPct = parseInt(line.trim()) || 0 }
        }
    }
    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: { diskProc.running = false; diskProc.running = true }
    }

    Process {
        id: mediaProc
        command: ["bash", "-c",
            "playerctl metadata --format " +
            "'{{status}}|{{title}}|{{artist}}|{{position}}|{{mpris:length}}|{{mpris:artUrl}}'" +
            " 2>/dev/null || echo 'Stopped|Nothing playing|||0|0|'"]
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.split("|")
                sidebar.mediaStatus = p[0] || "Stopped"
                sidebar.mediaTitle  = (p[1] && p[1] !== "") ? p[1] : "Nothing playing"
                sidebar.mediaArtist = p[2] || ""
                var pos = parseFloat(p[3]) || 0
                var len = parseFloat(p[4]) || 0
                sidebar.mediaPct = len > 0 ? Math.min(100, pos / len * 100) : 0
                var art = (p[5] || "").trim()
                sidebar.mediaArt = (art.startsWith("file://") || art.startsWith("http")) ? art : ""
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: if (!mediaProc.running) mediaProc.running = true
    }

    // ── Root layout ──────────────────────────────────────────────────────────
    width:  300
    color:  c_bg

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ════════════════════════════════════════════════════════════════════
        // PAGES
        // ════════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Page 0 : Home ─────────────────────────────────────────────
            Flickable {
                anchors.fill: parent
                contentHeight: homeCol.implicitHeight
                clip: true
                visible: sidebar.currentPage === 0
                interactive: contentHeight > height

                ColumnLayout {
                    id: homeCol
                    width: parent.width
                    spacing: 0

                    Item { height: 40; Layout.fillWidth: true }

                    // Big clock — hour (fg) + minutes (red)
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0
                        Text {
                            text: Qt.formatTime(sidebar.clockNow, "hh")
                            color: sidebar.c_fg
                            font.pixelSize: 72
                            font.family: sidebar.ff
                            font.weight: Font.Bold
                        }
                        Text {
                            text: Qt.formatTime(sidebar.clockNow, "mm")
                            color: sidebar.c_x1
                            font.pixelSize: 72
                            font.family: sidebar.ff
                            font.weight: Font.Normal
                        }
                    }

                    Item { height: 20; Layout.fillWidth: true }

                    // Day-of-week strip
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Repeater {
                            model: 7

                            Rectangle {
                                required property int index
                                // today's Mon-indexed day: (getDay()+6)%7
                                readonly property int todayIdx: (sidebar.clockNow.getDay() + 6) % 7
                                readonly property bool isToday: index === todayIdx
                                readonly property int  dayNum: {
                                    var d = new Date(sidebar.clockNow)
                                    d.setDate(d.getDate() + (index - todayIdx))
                                    return d.getDate()
                                }

                                width: 34; height: 54; radius: 8
                                color: isToday ? sidebar.c_s0 : "transparent"

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: sidebar.dayLetters[index]
                                        color: sidebar.dayColors[index]
                                        font.pixelSize: 15
                                        font.family: sidebar.ff
                                        font.bold: true
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dayNum
                                        color: isToday ? sidebar.c_fg : sidebar.c_dim
                                        font.pixelSize: 10
                                        font.family: sidebar.ff
                                    }
                                }
                            }
                        }
                    }

                    Item { height: 24; Layout.fillWidth: true }

                    // Weather
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        Text {
                            text: sidebar.wxTemp
                            color: sidebar.c_fg
                            font.pixelSize: 15; font.family: sidebar.ff; font.bold: true
                        }
                        Text {
                            text: sidebar.wxDesc
                            color: sidebar.c_dim
                            font.pixelSize: 12; font.family: sidebar.ff
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { height: 28; Layout.fillWidth: true }

                    // System stats — labeled horizontal bars
                    ColumnLayout {
                        Layout.leftMargin: 34
                        Layout.rightMargin: 34
                        Layout.fillWidth: true
                        spacing: 14

                        // Vol
                        StatBar { label: "Vol"; value: sidebar.volPct; barColor: sidebar.c_x5 }
                        StatBar { label: "CPU"; value: sidebar.cpuPct; barColor: sidebar.c_x2 }
                        StatBar { label: "GPU"; value: sidebar.gpuPct; barColor: sidebar.c_x9 }
                        StatBar { label: "RAM"; value: sidebar.memPct; barColor: sidebar.c_x12 }
                        StatBar { label: "Dsk"; value: sidebar.diskPct; barColor: sidebar.c_x6 }
                    }

                    Item { height: 40; Layout.fillWidth: true }
                }
            }

            // ── Page 1 : Calendar ─────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: sidebar.currentPage === 1

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 16; topMargin: 30; bottomMargin: 10
                    }
                    spacing: 8

                    // Month / year nav
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "<"; color: sidebar.c_dim
                            font.pixelSize: 16; font.family: sidebar.ff
                            padding: 6
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (sidebar.calMonth === 0) { sidebar.calMonth = 11; sidebar.calYear-- }
                                    else sidebar.calMonth--
                                }
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sidebar.monthNames[sidebar.calMonth]
                                color: sidebar.c_x2
                                font.pixelSize: 14; font.family: sidebar.ff; font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: sidebar.calYear
                                color: sidebar.c_dim
                                font.pixelSize: 11; font.family: sidebar.ff
                            }
                        }
                        Text {
                            text: ">"; color: sidebar.c_dim
                            font.pixelSize: 16; font.family: sidebar.ff
                            padding: 6
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (sidebar.calMonth === 11) { sidebar.calMonth = 0; sidebar.calYear++ }
                                    else sidebar.calMonth++
                                }
                            }
                        }
                    }

                    // Day-of-week headers (colored Mon–Sun)
                    Row {
                        Layout.fillWidth: true
                        Repeater {
                            model: sidebar.dayLetters
                            Text {
                                width: (300 - 32) / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: sidebar.dayColors[index]
                                font.pixelSize: 12; font.family: sidebar.ff; font.bold: true
                            }
                        }
                    }

                    // Calendar grid
                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: 6
                            Row {
                                id: calRow
                                required property int index
                                readonly property int ri: index
                                spacing: 0

                                Repeater {
                                    model: 7
                                    Rectangle {
                                        required property int index
                                        readonly property var cell: sidebar.calCells[calRow.ri * 7 + index] || { day: 0, inMonth: false }
                                        readonly property bool isToday: cell.inMonth
                                            && cell.day === sidebar.clockNow.getDate()
                                            && sidebar.calMonth === sidebar.clockNow.getMonth()
                                            && sidebar.calYear  === sidebar.clockNow.getFullYear()

                                        width: (300 - 32) / 7; height: 28; radius: 4
                                        color: isToday ? sidebar.c_fg : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.cell.day
                                            color: parent.isToday    ? sidebar.c_bg
                                                 : parent.cell.inMonth ? sidebar.c_fg
                                                 : sidebar.c_dim
                                            font.pixelSize: 11; font.family: sidebar.ff
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ── Page 2 : Media ────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: sidebar.currentPage === 2

                ColumnLayout {
                    anchors { fill: parent; margins: 20; topMargin: 40 }
                    spacing: 16

                    // Album art circle + progress ring
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 160; height: 160

                        Rectangle {
                            anchors.centerIn: parent
                            width: 148; height: 148; radius: 74
                            color: sidebar.c_s0; clip: true

                            Image {
                                anchors.fill: parent
                                source: sidebar.mediaArt || ""
                                fillMode: Image.PreserveAspectCrop
                                visible: sidebar.mediaArt !== "" && status === Image.Ready
                            }
                        }

                        Canvas {
                            id: progressRing
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                // dim backdrop ring
                                ctx.beginPath()
                                ctx.arc(width/2, height/2, 77, 0, Math.PI * 2)
                                ctx.strokeStyle = sidebar.c_dim
                                ctx.lineWidth = 6; ctx.globalAlpha = 0.3; ctx.stroke()
                                // progress arc
                                if (sidebar.mediaPct > 0) {
                                    ctx.globalAlpha = 1.0
                                    ctx.beginPath()
                                    ctx.arc(width/2, height/2, 77,
                                            -Math.PI / 2,
                                            -Math.PI / 2 + (sidebar.mediaPct / 100) * Math.PI * 2)
                                    ctx.strokeStyle = sidebar.c_x5
                                    ctx.lineWidth = 6; ctx.stroke()
                                }
                            }
                            Connections {
                                target: sidebar
                                function onMediaPctChanged() { progressRing.requestPaint() }
                            }
                        }
                    }

                    // Title + artist
                    Text {
                        Layout.fillWidth: true
                        text: sidebar.mediaTitle
                        color: sidebar.c_fg
                        font.pixelSize: 13; font.family: sidebar.ff; font.bold: true
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: sidebar.mediaArtist || "Unknown artist"
                        color: sidebar.c_dim
                        font.pixelSize: 11; font.family: sidebar.ff
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }

                    // 20-bar visualizer (static heights, lights up with progress)
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 3

                        readonly property var bh: [8,16,24,32,40,32,24,32,40,32,32,40,32,24,32,40,32,24,16,8]
                        readonly property var bc: [
                            sidebar.c_x1, sidebar.c_x3, sidebar.c_x2, sidebar.c_x6, sidebar.c_x4, sidebar.c_x5,
                            sidebar.c_x1, sidebar.c_x3, sidebar.c_x2, sidebar.c_x6, sidebar.c_x4, sidebar.c_x5,
                            sidebar.c_x1, sidebar.c_x3, sidebar.c_x2, sidebar.c_x6, sidebar.c_x4, sidebar.c_x5,
                            sidebar.c_x1, sidebar.c_x3
                        ]

                        Repeater {
                            model: 20
                            Rectangle {
                                required property int index
                                readonly property bool reached: (sidebar.mediaPct * 20 / 100) >= (index + 1)
                                width: 8; height: parent.bh[index]; radius: 4
                                color: parent.bc[index]
                                opacity: reached ? 1.0 : 0.15
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                    }

                    // Playback controls
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 16

                        Rectangle {
                            width: 50; height: 40; radius: 8; color: sidebar.c_s0
                            Text {
                                anchors.centerIn: parent
                                text: "⏮"; color: sidebar.c_x5; font.pixelSize: 20
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!prevProc.running) prevProc.running = true
                            }
                            Process {
                                id: prevProc
                                command: ["playerctl", "previous"]
                                onRunningChanged: if (!running) Qt.callLater(function() { mediaProc.running = true })
                            }
                        }

                        Rectangle {
                            width: 50; height: 50; radius: 25
                            color: sidebar.c_bg
                            border.width: 2
                            border.color: sidebar.mediaStatus === "Playing" ? sidebar.c_x6 : sidebar.c_dim
                            Text {
                                anchors.centerIn: parent
                                text: sidebar.mediaStatus === "Playing" ? "⏸" : "▶"
                                color: sidebar.mediaStatus === "Playing" ? sidebar.c_x6 : sidebar.c_dim
                                font.pixelSize: 20
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!pauseProc.running) pauseProc.running = true
                            }
                            Process {
                                id: pauseProc
                                command: ["playerctl", "play-pause"]
                                onRunningChanged: if (!running) Qt.callLater(function() { mediaProc.running = true })
                            }
                        }

                        Rectangle {
                            width: 50; height: 40; radius: 8; color: sidebar.c_s0
                            Text {
                                anchors.centerIn: parent
                                text: "⏭"; color: sidebar.c_x5; font.pixelSize: 20
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (!nextProc.running) nextProc.running = true
                            }
                            Process {
                                id: nextProc
                                command: ["playerctl", "next"]
                                onRunningChanged: if (!running) Qt.callLater(function() { mediaProc.running = true })
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // PAGE INDICATORS
        // ════════════════════════════════════════════════════════════════════
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            topPadding: 8; bottomPadding: 16

            readonly property var pageColors: [sidebar.c_x1, sidebar.c_x2, sidebar.c_x5]

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property bool active: index === sidebar.currentPage
                    width: active ? 26 : 12; height: 12; radius: 6
                    color: parent.pageColors[index]
                    opacity: active ? 1.0 : 0.3

                    Behavior on width   { NumberAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: sidebar.currentPage = index
                    }
                }
            }
        }
    }

    // ── Inline component: labelled progress bar ──────────────────────────────
    component StatBar: RowLayout {
        required property string label
        required property real   value
        required property color  barColor
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: label; color: sidebar.c_dim
            font.pixelSize: 10; font.family: sidebar.ff
            Layout.preferredWidth: 26
        }
        Rectangle {
            Layout.fillWidth: true; height: 6; radius: 3; color: sidebar.c_s0
            Rectangle {
                width: Math.max(0, Math.min(1, value / 100)) * parent.width
                height: parent.height; radius: 3; color: barColor
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
        Text {
            text: Math.round(value) + "%"; color: sidebar.c_dim
            font.pixelSize: 10; font.family: sidebar.ff
            Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
        }
    }
}
