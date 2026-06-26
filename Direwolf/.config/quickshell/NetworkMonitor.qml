import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string text: "Disconnected"

    property Process _proc: Process {
        running: true
        command: ["bash", "-c", "while true; do line=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep -v ':loopback:' | head -1); echo \"${line:-DISCONNECTED}\"; sleep 5; done"]
        stdout: SplitParser {
            onRead: line => {
                if (line === "DISCONNECTED" || !line) {
                    root.text = "Disconnected"
                    return
                }
                const parts = line.split(":")
                const name = parts[0] || ""
                const type = parts[1] || ""
                const device = parts[2] || ""
                root.text = type.indexOf("wireless") !== -1 ? ("Wi-Fi " + name) : ("Net " + device)
            }
        }
    }
}
