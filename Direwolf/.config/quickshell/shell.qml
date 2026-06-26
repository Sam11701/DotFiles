import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire

Scope {
    id: rootScope

    property bool calendarOpen: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    SysMonitor { id: sysMonitor }
    NetworkMonitor { id: netMonitor }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        property var now: new Date()
        onTriggered: now = new Date()
    }

    Process {
        id: pwcenterProc
        command: ["hyprpwcenter"]
    }

    // Bar — one per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
            readonly property real uiScale: modelData.width / 1920

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 22 * uiScale
            color: Colors.background

            // Left: workspaces
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10 * panel.uiScale
                spacing: 10 * panel.uiScale

                Repeater {
                    model: Hyprland.workspaces

                    Text {
                        required property var modelData
                        visible: modelData.monitor === panel.hyprMonitor
                        text: modelData.id
                        color: modelData.active ? Colors.foreground : Colors.surfaceForeground
                        font.pixelSize: 11 * panel.uiScale
                        font.family: "Overpass Mono"
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            // Center: date (clickable to open calendar)
            Text {
                anchors.centerIn: parent
                color: Colors.surfaceForeground
                font.pixelSize: 11 * panel.uiScale
                font.family: "Overpass Mono"
                text: Qt.formatDateTime(clockTimer.now, "dddd, dd MMMM  hh:mm AP")

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rootScope.calendarOpen = !rootScope.calendarOpen
                }
            }

            // Right: stats
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10 * panel.uiScale
                spacing: 12 * panel.uiScale

                Text {
                    color: Colors.surfaceForeground
                    font.pixelSize: 11 * panel.uiScale
                    font.family: "Overpass Mono"
                    text: {
                        const sink = Pipewire.defaultAudioSink
                        if (!sink || !sink.audio) return "Vol --"
                        return sink.audio.muted ? "Muted" : "Vol " + Math.round(sink.audio.volume * 100) + "%"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: pwcenterProc.startDetached()
                    }
                }

                Text {
                    color: netMonitor.text === "Disconnected" ? Colors.primary : Colors.surfaceForeground
                    font.pixelSize: 11 * panel.uiScale
                    font.family: "Overpass Mono"
                    text: netMonitor.text
                }

                Text {
                    color: Colors.surfaceForeground
                    font.pixelSize: 11 * panel.uiScale
                    font.family: "Overpass Mono"
                    text: "CPU " + sysMonitor.cpu + "%  GPU " + sysMonitor.gpu + "%  Mem " + sysMonitor.mem + "%"
                }
            }
        }
    }

    // Calendar overlay — one per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: calendarOverlay
            required property var modelData
            screen: modelData
            readonly property real uiScale: modelData.width / 1920

            WlrLayershell.namespace: "qs-calendar"
            visible: rootScope.calendarOpen
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            color: "transparent"

            // Click outside calendar to close
            MouseArea {
                anchors.fill: parent
                onClicked: rootScope.calendarOpen = false
            }

            CalendarWidget {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 26 * calendarOverlay.uiScale

                // Swallow clicks so they don't reach the close MouseArea
                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // consume
                }
            }
        }
    }
}
