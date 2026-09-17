import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire

Scope {
    id: shellRoot

    property bool showWorkspaces:  true
    property bool showWindowTitle: true
    property bool showClock:       true
    property bool showSystemTray:  true
    property bool showVolume:      true
    property bool showNetwork:     true
    property bool showCpu:         true
    property bool showGpu:         true
    property bool showMem:         true
    property bool barPillMode:     true
    property real barOpacity:      0.82

    Process {
        id: barConfigLoader
        running: true
        command: ["bash", "-c", "python3 -c \"import json; d=json.load(open('/home/sam/.config/quickshell/bar-config.json')); print(json.dumps(d))\" 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const cfg = JSON.parse(data)
                    if (cfg.pillMode !== undefined) shellRoot.barPillMode    = cfg.pillMode
                    if (cfg.opacity  !== undefined) shellRoot.barOpacity     = cfg.opacity
                    const w = cfg.widgets || {}
                    if (w.workspaces  !== undefined) shellRoot.showWorkspaces  = w.workspaces
                    if (w.windowTitle !== undefined) shellRoot.showWindowTitle = w.windowTitle
                    if (w.clock       !== undefined) shellRoot.showClock       = w.clock
                    if (w.systemTray  !== undefined) shellRoot.showSystemTray  = w.systemTray
                    if (w.volume      !== undefined) shellRoot.showVolume      = w.volume
                    if (w.network     !== undefined) shellRoot.showNetwork     = w.network
                    if (w.cpu         !== undefined) shellRoot.showCpu         = w.cpu
                    if (w.gpu         !== undefined) shellRoot.showGpu         = w.gpu
                    if (w.mem         !== undefined) shellRoot.showMem         = w.mem
                } catch(e) {}
            }
        }
    }

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

    FileView {
        id: clockFormatFile
        path: Qt.resolvedUrl("file:///home/sam/.config/quickshell/clock_format")
        watchChanges: true
        property string fmt: "ddd dd MMM  hh:mm"
        Component.onCompleted: {
            const f = clockFormatFile.text().trim()
            if (f.length > 0) fmt = f
        }
        onFileChanged: {
            const f = clockFormatFile.text().trim()
            if (f.length > 0) fmt = f
        }
    }

    Process {
        id: pwcenterProc
        command: ["hyprpwcenter"]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            readonly property var hyprMonitor: Hyprland.monitorFor(modelData)
            // Same physical bar size across monitors of differing resolution
            // (e.g. the 1920x1080 and 2560x1440 outputs here are both 27in
            // panels, so 2560-wide needs everything ~1.33x bigger in pixels
            // to look the same size as on the 1920-wide one).
            readonly property real uiScale: Math.min(modelData.width, modelData.height) / 1080

            Process {
                id: rotateCwProc
                command: ["python3", "/home/sam/.config/quickshell/rotate-monitor.py",
                          panel.modelData.name, "1"]
            }

            Process {
                id: rotateCcwProc
                command: ["python3", "/home/sam/.config/quickshell/rotate-monitor.py",
                          panel.modelData.name, "-1"]
            }

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 30 * uiScale
            color: shellRoot.barPillMode ? Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0) : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, shellRoot.barOpacity)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8 * panel.uiScale
                anchors.rightMargin: 8 * panel.uiScale
                spacing: 0

                // Left: workspaces + window title
                Row {
                    spacing: 6 * panel.uiScale

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showWorkspaces
                        pillMode: shellRoot.barPillMode

                        Repeater {
                            model: Hyprland.workspaces

                            Text {
                                required property var modelData
                                visible: modelData.monitor === panel.hyprMonitor
                                text: modelData.id
                                color: modelData.active ? Colors.primary : Colors.surfaceForeground
                                font.pixelSize: 11 * panel.uiScale

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.activate()
                                }
                            }
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showWindowTitle
                        pillMode: shellRoot.barPillMode

                        Text {
                            width: Math.min(implicitWidth, 280 * panel.uiScale)
                            elide: Text.ElideRight
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop"
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Center: clock
                Pill {
                    Layout.alignment: Qt.AlignVCenter
                    uiScale: panel.uiScale
                    visible: shellRoot.showClock
                    pillMode: shellRoot.barPillMode
                    Text {
                        color: Colors.foreground
                        font.pixelSize: 11 * panel.uiScale
                        text: Qt.formatDateTime(clockTimer.now, clockFormatFile.fmt)
                    }
                }

                Item { Layout.fillWidth: true }

                // Right: system tray, stats, rotate buttons
                Row {
                    spacing: 6 * panel.uiScale

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showSystemTray && SystemTray.items.values.length > 0
                        pillMode: shellRoot.barPillMode

                        Repeater {
                            model: SystemTray.items

                            Image {
                                required property var modelData
                                source: modelData.icon
                                sourceSize: Qt.size(13 * panel.uiScale, 13 * panel.uiScale)
                                width: 13 * panel.uiScale
                                height: 13 * panel.uiScale

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.activate()
                                }
                            }
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showVolume
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: Colors.primary
                            font.pixelSize: 11 * panel.uiScale
                            text: {
                                const sink = Pipewire.defaultAudioSink
                                if (!sink || !sink.audio) return "No Audio"
                                return sink.audio.muted ? "Muted" : "Vol " + Math.round(sink.audio.volume * 100) + "%"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: pwcenterProc.startDetached()
                            }
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showNetwork
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: netMonitor.text === "Disconnected" ? "#ff5555" : Colors.secondary
                            font.pixelSize: 11 * panel.uiScale
                            text: netMonitor.text
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showCpu
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: "CPU " + sysMonitor.cpu + "%"
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showGpu
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: "GPU " + sysMonitor.gpu + "%"
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        visible: shellRoot.showMem
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: "Mem " + sysMonitor.mem + "%"
                        }
                    }

                    Pill {
                        anchors.verticalCenter: parent.verticalCenter
                        uiScale: panel.uiScale
                        pillMode: shellRoot.barPillMode

                        Text {
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: "CW"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: rotateCwProc.startDetached()
                            }
                        }

                        Text {
                            color: Colors.foreground
                            font.pixelSize: 11 * panel.uiScale
                            text: "CCW"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: rotateCcwProc.startDetached()
                            }
                        }
                    }
                }
            }
        }
    }
}
