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

    property bool sidebarOpen: false
    property int  sidebarPage: 0

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

    // ── Bar (one per screen) ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            readonly property var  hyprMonitor: Hyprland.monitorFor(modelData)
            readonly property real uiScale: modelData.width / 1920

            anchors { top: true; left: true; right: true }
            implicitHeight: 22 * uiScale
            color: Colors.background

            // Left: sidebar toggle + workspaces
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8 * panel.uiScale
                spacing: 10 * panel.uiScale

                Text {
                    text: "≡"
                    color: rootScope.sidebarOpen && rootScope.sidebarPage === 0
                           ? Colors.foreground : Colors.surfaceForeground
                    font.pixelSize: 14 * panel.uiScale
                    font.family: "Overpass Mono"
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rootScope.sidebarOpen && rootScope.sidebarPage === 0)
                                rootScope.sidebarOpen = false
                            else {
                                rootScope.sidebarPage = 0
                                rootScope.sidebarOpen = true
                            }
                        }
                    }
                }

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

            // Center: date — click opens sidebar calendar page
            Text {
                anchors.centerIn: parent
                color: Colors.surfaceForeground
                font.pixelSize: 11 * panel.uiScale
                font.family: "Overpass Mono"
                text: Qt.formatDateTime(clockTimer.now, "dddd, dd MMMM  hh:mm AP")

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rootScope.sidebarOpen && rootScope.sidebarPage === 1)
                            rootScope.sidebarOpen = false
                        else {
                            rootScope.sidebarPage = 1
                            rootScope.sidebarOpen = true
                        }
                    }
                }
            }

            // Right: vol / net / cpu-gpu-mem
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

    // ── Sidebar overlay (one per screen) ────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-sidebar"
            visible: rootScope.sidebarOpen
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            // Click anywhere on the dim area to close
            MouseArea {
                anchors.fill: parent
                onClicked: rootScope.sidebarOpen = false
            }

            // Sidebar panel (left edge, 300px)
            Item {
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                width: 300

                // Swallow background clicks so they don't reach the close handler
                MouseArea { anchors.fill: parent; onClicked: {} }

                Sidebar {
                    anchors.fill: parent
                    clockNow:     clockTimer.now
                    cpuPct:       sysMonitor.cpu
                    gpuPct:       sysMonitor.gpu
                    memPct:       sysMonitor.mem
                    currentPage:  rootScope.sidebarPage
                    onCurrentPageChanged: rootScope.sidebarPage = currentPage
                }
            }
        }
    }

    // ── Left-edge hover activator (hidden while sidebar is open) ────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "qs-edge-l"
            exclusionMode: ExclusionMode.Ignore
            visible: !rootScope.sidebarOpen

            anchors { top: true; left: true; bottom: true }
            implicitWidth: 2
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: edgeTimer.restart()
                onExited: edgeTimer.stop()

                Timer {
                    id: edgeTimer
                    interval: 350
                    onTriggered: {
                        rootScope.sidebarPage = 0
                        rootScope.sidebarOpen = true
                    }
                }
            }
        }
    }
}
