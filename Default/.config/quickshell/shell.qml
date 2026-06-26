import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire

Scope {
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
            readonly property real uiScale: modelData.width / 1920

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 30 * uiScale
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8 * panel.uiScale
                spacing: 6 * panel.uiScale

                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    uiScale: panel.uiScale

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

                    Text {
                        width: Math.min(implicitWidth, 280 * panel.uiScale)
                        elide: Text.ElideRight
                        color: Colors.foreground
                        font.pixelSize: 11 * panel.uiScale
                        text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop"
                    }
                }
            }

            Pill {
                anchors.centerIn: parent
                uiScale: panel.uiScale

                Text {
                    color: Colors.foreground
                    font.pixelSize: 11 * panel.uiScale
                    text: Qt.formatDateTime(clockTimer.now, "ddd dd MMM  hh:mm")
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 8 * panel.uiScale
                spacing: 6 * panel.uiScale

                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    uiScale: panel.uiScale
                    visible: SystemTray.items.values.length > 0

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

                    Text {
                        color: netMonitor.text === "Disconnected" ? "#ff5555" : Colors.secondary
                        font.pixelSize: 11 * panel.uiScale
                        text: netMonitor.text
                    }
                }

                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    uiScale: panel.uiScale

                    Text {
                        color: Colors.foreground
                        font.pixelSize: 11 * panel.uiScale
                        text: "CPU " + sysMonitor.cpu + "%"
                    }
                }

                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    uiScale: panel.uiScale

                    Text {
                        color: Colors.foreground
                        font.pixelSize: 11 * panel.uiScale
                        text: "GPU " + sysMonitor.gpu + "%"
                    }
                }

                Pill {
                    anchors.verticalCenter: parent.verticalCenter
                    uiScale: panel.uiScale

                    Text {
                        color: Colors.foreground
                        font.pixelSize: 11 * panel.uiScale
                        text: "Mem " + sysMonitor.mem + "%"
                    }
                }
            }
        }
    }
}
