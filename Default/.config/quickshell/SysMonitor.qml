import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int cpu: 0
    property int mem: 0
    property int gpu: 0

    property Process _proc: Process {
        running: true
        command: ["bash", "-c", "while true; do read -r _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 g1 gn1 < /proc/stat; sleep 1; read -r _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 g2 gn2 < /proc/stat; t1=$((u1+n1+s1+i1+iw1+irq1+sirq1+st1)); t2=$((u2+n2+s2+i2+iw2+irq2+sirq2+st2)); td=$((t2-t1)); id=$((i2-i1)); if [ \"$td\" -gt 0 ]; then cpu=$(( (1000*(td-id)/td+5)/10 )); else cpu=0; fi; mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%d\", (t-a)*100/t}' /proc/meminfo); echo \"$cpu $mem\"; done"]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split(/\s+/)
                root.cpu = parseInt(parts[0]) || 0
                root.mem = parseInt(parts[1]) || 0
            }
        }
    }

    property Process _gpuProc: Process {
        running: true
        command: ["bash", "-c", "while true; do nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0; sleep 1; done"]
        stdout: SplitParser {
            onRead: line => { root.gpu = parseInt(line.trim()) || 0 }
        }
    }
}
