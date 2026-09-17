//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
ApplicationWindow {
    id: root
    title: "Settings"
    width: 1000; height: 700
    minimumWidth: 750; minimumHeight: 500
    visible: true
    onClosing: Qt.quit()
    color: Colors.background

    property int currentPage: 0
    property real currentVolume: 0.5
    property bool currentMuted: false

    // Interface page — populated from hyprctl on startup
    property int  hyprGapsIn:      2
    property int  hyprGapsOut:     5
    property int  hyprBorderSz:    3
    property int  hyprRounding:    10
    property real hyprActiveOp:    1.0
    property real hyprInactiveOp:  1.0
    property bool hyprBlurEnabled: true
    property int  hyprBlurSz:      3
    property int  hyprBlurPasses:  1
    property bool hyprAnimEnabled: true

    // Display page
    property int  hyprVRR:       0
    property int  sunsetTemp:    4000
    property bool sunsetEnabled: false

    // Power & Sleep (hypridle timeouts, in minutes; enabled = listener block exists)
    property int  idleLockMins:       10
    property int  idleDisplayMins:    11
    property int  idleSleepMins:      30
    property bool idleLockEnabled:    true
    property bool idleDisplayEnabled: true
    property bool idleSleepEnabled:   true

    // Bar widget config (persisted to bar-config.json)
    property bool barPillMode:        true
    property real barOpacity:         0.82
    property bool barShowWorkspaces:  true
    property bool barShowWindowTitle: true
    property bool barShowClock:       true
    property bool barShowSystemTray:  true
    property bool barShowVolume:      true
    property bool barShowNetwork:     true
    property bool barShowCpu:         true
    property bool barShowGpu:         true
    property bool barShowMem:         true

    // Shortcut overrides: lua action → current key combo (persisted to disk)
    property var _overrides: ({})
    signal overridesLoaded()

    // Read current wallpaper path from waypaper config
    Process {
        id: wallpaperReader
        running: true
        command: ["bash", "-c", "grep -m1 '^wallpaper = ' ~/.config/waypaper/config.ini | sed 's/wallpaper = //' | sed \"s|^~/|$HOME/|\" | tr -d '\\n'"]
        property string path: ""
        stdout: SplitParser { onRead: data => wallpaperReader.path = data.trim() }
    }

    Process {
        id: overridesReader
        running: true
        command: ["bash", "-c", "cat /home/sam/.config/quickshell/shortcut-overrides.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: data => {
                try { root._overrides = JSON.parse(data.trim()); root.overridesLoaded() } catch(e) {}
            }
        }
    }

    Process {
        id: barConfigReader
        running: true
        command: ["bash", "-c", "cat /home/sam/.config/quickshell/bar-config.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const cfg = JSON.parse(data.trim())
                    if (cfg.pillMode !== undefined) root.barPillMode    = cfg.pillMode
                    if (cfg.opacity  !== undefined) root.barOpacity     = cfg.opacity
                    const w = cfg.widgets || {}
                    if (w.workspaces  !== undefined) root.barShowWorkspaces  = w.workspaces
                    if (w.windowTitle !== undefined) root.barShowWindowTitle = w.windowTitle
                    if (w.clock       !== undefined) root.barShowClock       = w.clock
                    if (w.systemTray  !== undefined) root.barShowSystemTray  = w.systemTray
                    if (w.volume      !== undefined) root.barShowVolume      = w.volume
                    if (w.network     !== undefined) root.barShowNetwork     = w.network
                    if (w.cpu         !== undefined) root.barShowCpu         = w.cpu
                    if (w.gpu         !== undefined) root.barShowGpu         = w.gpu
                    if (w.mem         !== undefined) root.barShowMem         = w.mem
                } catch(e) {}
            }
        }
    }

    // Read current volume + mute state from pipewire via wpctl
    Process {
        id: volumeReader
        running: true
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                const v = parseFloat(parts[1])
                if (!isNaN(v)) {
                    root.currentVolume = v
                    volumeSlider.value = Math.min(v, 1.5)
                }
                root.currentMuted = data.includes("MUTED")
            }
        }
    }

    Process {
        id: interfaceReader
        running: true
        command: ["bash", "-c",
            "echo gaps_in=$(hyprctl getoption general:gaps_in -j | jq -r '.css | split(\" \")[0]');" +
            "echo gaps_out=$(hyprctl getoption general:gaps_out -j | jq -r '.css | split(\" \")[0]');" +
            "echo border_size=$(hyprctl getoption general:border_size -j | jq -r '.int');" +
            "echo rounding=$(hyprctl getoption decoration:rounding -j | jq -r '.int');" +
            "echo active_opacity=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float');" +
            "echo inactive_opacity=$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float');" +
            "echo blur_enabled=$(hyprctl getoption decoration:blur:enabled -j | jq -r 'if .bool then \"1\" else \"0\" end');" +
            "echo blur_size=$(hyprctl getoption decoration:blur:size -j | jq -r '.int');" +
            "echo blur_passes=$(hyprctl getoption decoration:blur:passes -j | jq -r '.int');" +
            "echo anim_enabled=$(hyprctl getoption animations:enabled -j | jq -r 'if .bool then \"1\" else \"0\" end');" +
            "echo vrr=$(hyprctl getoption misc:vrr -j | jq -r '.int')"
        ]
        stdout: SplitParser {
            onRead: data => {
                const eq = data.indexOf('=')
                if (eq < 0) return
                const k = data.substring(0, eq), v = data.substring(eq + 1).trim()
                const i = parseInt(v), f = parseFloat(v)
                if      (k === 'gaps_in')          { if (!isNaN(i)) root.hyprGapsIn      = i }
                else if (k === 'gaps_out')         { if (!isNaN(i)) root.hyprGapsOut     = i }
                else if (k === 'border_size')      { if (!isNaN(i)) root.hyprBorderSz    = i }
                else if (k === 'rounding')         { if (!isNaN(i)) root.hyprRounding    = i }
                else if (k === 'active_opacity')   { if (!isNaN(f)) root.hyprActiveOp    = f }
                else if (k === 'inactive_opacity') { if (!isNaN(f)) root.hyprInactiveOp  = f }
                else if (k === 'blur_enabled')     root.hyprBlurEnabled = v === '1'
                else if (k === 'blur_size')        { if (!isNaN(i)) root.hyprBlurSz      = i }
                else if (k === 'blur_passes')      { if (!isNaN(i)) root.hyprBlurPasses  = i }
                else if (k === 'anim_enabled')     root.hyprAnimEnabled = v === '1'
                else if (k === 'vrr')              { if (!isNaN(i)) root.hyprVRR = i }
            }
        }
    }

    // ── Border color state (read from colors.lua) ─────────────────
    property int    _borderLine:    0
    property string borderActive1:  "00d4ffee"
    property string borderActive2:  "7b5ea7ee"
    property string borderInactive: "959181aa"

    Process {
        id: borderReader
        running: true
        command: ["bash", "-c", "grep -oP '(?<=rgba\\()[0-9a-f]+' ~/.config/hypr/colors.lua"]
        stdout: SplitParser {
            onRead: data => {
                const v = data.trim()
                if (!v) return
                if      (root._borderLine === 0) root.borderActive1  = v
                else if (root._borderLine === 1) root.borderActive2  = v
                else if (root._borderLine === 2) root.borderInactive = v
                root._borderLine++
            }
        }
    }

    // ── Monitor model (populated from hyprctl on startup) ─────────
    ListModel { id: monitorModel }
    ListModel { id: runtimeAppsModel }
    ListModel { id: runtimeNavModel }
    ListModel { id: runtimeMoveModel }
    ListModel { id: runtimeToolsModel }

    // ── Shortcut data — stable property vars so Repeater never recreates delegates ──
    readonly property var _appsData: [
        { k: "SUPER + Q", d: "Open terminal (kitty)",    lua: "hl.dsp.exec_cmd('kitty')" },
        { k: "SUPER + W", d: "Open browser (Brave)",     lua: "hl.dsp.exec_cmd('brave')" },
        { k: "SUPER + E", d: "Open file manager (nemo)", lua: "hl.dsp.exec_cmd('nemo')" },
        { k: "SUPER + R", d: "App launcher (rofi)",      lua: "hl.dsp.exec_cmd('rofi -show drun')" },
        { k: "SUPER + C", d: "Close focused window",     lua: "hl.dsp.window.close()" },
        { k: "SUPER + V", d: "Toggle float",             lua: "hl.dsp.window.float({action='toggle'})" },
        { k: "SUPER + P", d: "Toggle pseudo-tile",       lua: "hl.dsp.window.pseudo()" },
        { k: "SUPER + J", d: "Toggle split (dwindle)",   lua: "hl.dsp.layout('togglesplit')" },
        { k: "SUPER + M", d: "Exit Hyprland",            lua: "" }
    ]
    readonly property var _navData: [
        { k: "SUPER + ←/→/↑/↓", d: "Move focus in direction",   lua: "" },
        { k: "SUPER + 1–9, 0",   d: "Switch to workspace 1–10",  lua: "" },
        { k: "SUPER + scroll",   d: "Cycle workspaces",          lua: "" },
        { k: "SUPER + S",        d: "Toggle scratchpad (magic)", lua: "hl.dsp.workspace.toggle_special('magic')" }
    ]
    readonly property var _moveData: [
        { k: "SUPER + SHIFT + 1–0", d: "Move window to workspace 1–10",  lua: "" },
        { k: "SUPER + SHIFT + S",   d: "Send window to scratchpad",       lua: "hl.dsp.window.move({workspace='special:magic'})" },
        { k: "SUPER + ]",           d: "Move window to next monitor",     lua: "hl.dsp.window.move({monitor='+1'})" },
        { k: "SUPER + [",           d: "Move window to prev monitor",     lua: "hl.dsp.window.move({monitor='-1'})" },
        { k: "SUPER + CTRL + ]",    d: "Move workspace to next monitor",  lua: "hl.dsp.workspace.move({monitor='+1'})" },
        { k: "SUPER + CTRL + [",    d: "Move workspace to prev monitor",  lua: "hl.dsp.workspace.move({monitor='-1'})" },
        { k: "SUPER + LMB drag",    d: "Drag to move window",            lua: "" },
        { k: "SUPER + RMB drag",    d: "Drag to resize window",          lua: "" }
    ]
    readonly property var _toolsData: [
        { k: "Print",             d: "Screenshot full output",     lua: "hl.dsp.exec_cmd('hyprshot -m output -o /home/sam/Pictures')" },
        { k: "SHIFT + Print",     d: "Screenshot region select",   lua: "hl.dsp.exec_cmd('hyprshot -m region -o /home/sam/Pictures')" },
        { k: "SUPER + L",         d: "Lock screen (hyprlock)",     lua: "hl.dsp.exec_cmd('hyprlock')" },
        { k: "SUPER + I",         d: "Open this Settings panel",   lua: "hl.dsp.exec_cmd('qs -p ~/.config/quickshell/settings.qml')" },
        { k: "SUPER + SHIFT + C", d: "Color picker (hyprpicker)", lua: "hl.dsp.exec_cmd('hyprpicker -a -n')" },
        { k: "SUPER + SHIFT + V", d: "Cava visualizer popup",      lua: "hl.dsp.exec_cmd('kitty --class cava -e cava')" },
        { k: "SUPER + SHIFT + W", d: "Wallpaper picker",           lua: "hl.dsp.exec_cmd('wallpaper-picker')" },
        { k: "ALT+CTRL+SHIFT+V",  d: "Cursor clip toggle",         lua: "hl.dsp.exec_cmd('cursor-clip')" }
    ]
    readonly property var _mediaData: [
        { k: "Vol Up / Down", d: "Adjust volume ±5%",     lua: "" },
        { k: "Mute",          d: "Toggle audio mute",      lua: "" },
        { k: "Mic Mute",      d: "Toggle mic mute",        lua: "" },
        { k: "Brightness ±",  d: "Screen brightness ±5%", lua: "" },
        { k: "Play / Pause",  d: "Toggle media playback",  lua: "" },
        { k: "Next / Prev",   d: "Next / previous track",  lua: "" }
    ]

    // lua action → original default key, used to unbind stale static hyprland.lua binds
    readonly property var _defaultKeys: {
        const m = {}
        for (const item of _appsData)  if (item.lua) m[item.lua] = item.k
        for (const item of _navData)   if (item.lua) m[item.lua] = item.k
        for (const item of _moveData)  if (item.lua) m[item.lua] = item.k
        for (const item of _toolsData) if (item.lua) m[item.lua] = item.k
        return m
    }

    Process {
        id: monitorReader
        running: true
        command: ["bash", "-c",
            "hyprctl monitors -j | jq -r '.[] | [.name, (.width|tostring), (.height|tostring), (.refreshRate|floor|tostring), (.x|tostring), (.y|tostring), (.scale|tostring), (.availableModes|@json)] | join(\"|\")'"
        ]
        stdout: SplitParser {
            onRead: data => {
                const p = data.split('|')
                if (p.length < 8) return
                const w = parseInt(p[1]), h = parseInt(p[2])
                const allModes = JSON.parse(p[7])
                const prefix = `${w}x${h}@`
                const hzSet = new Set()
                for (const mode of allModes) {
                    if (mode.startsWith(prefix))
                        hzSet.add(Math.floor(parseFloat(mode.substring(prefix.length))))
                }
                const hzList = Array.from(hzSet).sort((a,b)=>a-b).join(',')
                monitorModel.append({
                    name: p[0], monWidth: w, monHeight: h,
                    hz: parseInt(p[3]), posX: parseInt(p[4]), posY: parseInt(p[5]),
                    monScale: parseFloat(p[6]), hzList
                })
            }
        }
    }

    Process {
        id: sunsetChecker
        running: true
        command: ["bash", "-c", "pgrep hyprsunset >/dev/null && echo 1 || echo 0"]
        stdout: SplitParser { onRead: data => root.sunsetEnabled = data.trim() === '1' }
    }

    Process {
        id: hypridleReader
        running: true
        command: ["bash", "-c",
            "echo lock_en=$(grep -c 'loginctl lock-session' ~/.config/hypr/hypridle.conf);" +
            "echo dpms_en=$(grep -c 'dpms off' ~/.config/hypr/hypridle.conf);" +
            "echo susp_en=$(grep -c 'systemctl suspend' ~/.config/hypr/hypridle.conf);" +
            "grep -E '[[:space:]]timeout = [[:digit:]]+' ~/.config/hypr/hypridle.conf | " +
            "awk 'NR==1{print \"lock_mins=\" int($3/60)} NR==2{print \"dpms_mins=\" int($3/60)} NR==3{print \"susp_mins=\" int($3/60)}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                const eq = data.indexOf('=')
                if (eq < 0) return
                const k = data.substring(0, eq), v = data.substring(eq + 1).trim()
                if      (k === 'lock_en')   root.idleLockEnabled    = v !== '0'
                else if (k === 'dpms_en')   root.idleDisplayEnabled = v !== '0'
                else if (k === 'susp_en')   root.idleSleepEnabled   = v !== '0'
                else if (k === 'lock_mins') { const i = parseInt(v); if (i > 0) root.idleLockMins    = i }
                else if (k === 'dpms_mins') { const i = parseInt(v); if (i > 0) root.idleDisplayMins = i }
                else if (k === 'susp_mins') { const i = parseInt(v); if (i > 0) root.idleSleepMins   = i }
            }
        }
    }

    // Re-reads actual applied scale from Hyprland (called after hl.monitor)
    Process {
        id: monitorScaleRefresher
        running: false
        command: ["bash", "-c", "sleep 0.4 && hyprctl monitors -j | jq -r '.[] | [.name, (.scale|tostring)] | join(\"|\")' "]
        stdout: SplitParser {
            onRead: data => {
                const p = data.split('|')
                if (p.length < 2) return
                const s = parseFloat(p[1])
                for (let i = 0; i < monitorModel.count; i++) {
                    if (monitorModel.get(i).name === p[0]) {
                        monitorModel.setProperty(i, "monScale", s)
                        break
                    }
                }
            }
        }
    }

    // ── Bar color model (read from Colors singleton) ───────────────
    ListModel {
        id: barColorModel
        ListElement { label: "Background";  key: "background";       hex: "0f1417" }
        ListElement { label: "Foreground";  key: "foreground";       hex: "dfe3e7" }
        ListElement { label: "Surface";     key: "surface";          hex: "41484d" }
        ListElement { label: "Surface Fg";  key: "surfaceForeground";hex: "c0c7cd" }
        ListElement { label: "Primary";     key: "primary";          hex: "90cef4" }
        ListElement { label: "Primary Fg";  key: "primaryForeground";hex: "00344a" }
        ListElement { label: "Secondary";   key: "secondary";        hex: "b6c9d7" }
        ListElement { label: "Tertiary";    key: "tertiary";         hex: "cbc1e9" }
        ListElement { label: "Error";       key: "errorColor";       hex: "ffb4ab" }
        ListElement { label: "Outline";     key: "outline";          hex: "8b9297" }
    }

    Component.onCompleted: {
        function h(c) {
            const s = c.toString()
            if (s.startsWith("#") && s.length === 9) return s.substring(3) // #AARRGGBB
            if (s.startsWith("#") && s.length === 7) return s.substring(1) // #RRGGBB
            return s.replace("#","").substring(0, 6)
        }
        const src = [Colors.background, Colors.foreground, Colors.surface, Colors.surfaceForeground,
                     Colors.primary, Colors.primaryForeground, Colors.secondary, Colors.tertiary,
                     Colors.errorColor, Colors.outline]
        for (let i = 0; i < src.length; i++)
            barColorModel.setProperty(i, "hex", h(src[i]))
    }

    function applyBarColors() {
        let parts = []
        for (let i = 0; i < barColorModel.count; i++) {
            const m = barColorModel.get(i)
            const h = m.hex.replace(/[^0-9a-fA-F]/g, "").substring(0, 6)
            if (h.length !== 6) continue
            const pat = `s|readonly property color ${m.key}: "#[^"]*"|readonly property color ${m.key}: "#${h}"|g`
            parts.push(`sed -i '${pat}' ~/.config/quickshell/Colors.qml`)
            parts.push(`sed -i '${pat}' ~/Projects/DotFiles/Default/.config/quickshell/Colors.qml`)
        }
        parts.push("systemctl --user restart quickshell.service")
        Quickshell.execDetached(["bash", "-c", parts.join(" && ")])
    }

    function applyMonitor(idx, newHz, newScale) {
        const m = monitorModel.get(idx)
        const h = (newHz    !== undefined) ? newHz    : m.hz
        const s = (newScale !== undefined) ? newScale : m.monScale
        Quickshell.execDetached(["bash", "-c",
            `hyprctl eval "hl.monitor({output='${m.name}',mode='${m.monWidth}x${m.monHeight}@${h}',position='${m.posX}x${m.posY}',scale='${s.toFixed(2)}'})" `])
        // Read back actual scale Hyprland snapped to (it rounds to keep integer logical px)
        monitorScaleRefresher.running = false
        monitorScaleRefresher.running = true
    }

    function applyBorderColors() {
        const a1 = root.borderActive1, a2 = root.borderActive2, ia = root.borderInactive
        const files = ["~/.config/hypr/colors.lua",
                       "~/Projects/DotFiles/Default/.config/hypr/colors.lua"]
        let parts = []
        for (const f of files) {
            parts.push(`sed -i 's|active_border_1 = "rgba([^"]*)"| active_border_1 = "rgba(${a1})"|' ${f}`)
            parts.push(`sed -i 's|active_border_2 = "rgba([^"]*)"| active_border_2 = "rgba(${a2})"|' ${f}`)
            parts.push(`sed -i 's|inactive_border = "rgba([^"]*)"| inactive_border = "rgba(${ia})"|' ${f}`)
        }
        parts.push(`hyprctl keyword general:col.active_border "rgba(${a1}) rgba(${a2}) 45deg"`)
        parts.push(`hyprctl keyword general:col.inactive_border "rgba(${ia})"`)
        Quickshell.execDetached(["bash", "-c", parts.join(" && ")])
    }

    function applyBarConfig() {
        const cfg = JSON.stringify({
            pillMode: root.barPillMode,
            opacity:  root.barOpacity,
            widgets: {
                workspaces:  root.barShowWorkspaces,
                windowTitle: root.barShowWindowTitle,
                clock:       root.barShowClock,
                systemTray:  root.barShowSystemTray,
                volume:      root.barShowVolume,
                network:     root.barShowNetwork,
                cpu:         root.barShowCpu,
                gpu:         root.barShowGpu,
                mem:         root.barShowMem
            }
        }, null, 2)
        Quickshell.execDetached(["python3", "-c",
            "import sys; open(sys.argv[2],'w').write(sys.argv[1])",
            cfg, "/home/sam/.config/quickshell/bar-config.json"
        ])
        Quickshell.execDetached(["bash", "-c",
            "sleep 0.3 && systemctl --user restart quickshell.service"
        ])
    }

    // ── Type definitions ──────────────────────────────────────────

    component NavBtn: Rectangle {
        required property int idx
        required property string lbl
        required property string ico
        Layout.fillWidth: true; height: 36; radius: 8
        color: root.currentPage === idx ? Colors.primary
             : ma.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentPage = idx
        }
        RowLayout {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: ico; font.pixelSize: 13
                   color: root.currentPage === idx ? Colors.primaryForeground : Colors.foreground }
            Text { text: lbl; font.pixelSize: 12
                   color: root.currentPage === idx ? Colors.primaryForeground : Colors.foreground }
        }
    }

    component Hdr: RowLayout {
        property string t: ""; property string i: ""
        Layout.fillWidth: true; spacing: 6
        Text { text: i; font.pixelSize: 13 }
        Text { text: t; color: Colors.primary; font.pixelSize: 13; font.bold: true }
    }

    component Card: Rectangle {
        default property alias items: col.data
        Layout.fillWidth: true
        color: Qt.rgba(1,1,1,0.04); radius: 8
        border { color: Qt.rgba(1,1,1,0.07); width: 1 }
        implicitHeight: col.implicitHeight + 24
        ColumnLayout {
            id: col
            anchors { fill: parent; margins: 12 }
            spacing: 10
        }
    }

    component Sep: Rectangle {
        Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.08)
    }

    component StubTag: Text {
        text: "[stub]"; color: Colors.errorColor
        font { pixelSize: 9; bold: true }
    }

    // Read-only badge row — used for runtime-appended shortcuts (no editable state needed)
    component ShortcutRow: RowLayout {
        property string keys: ""
        property string desc: ""
        Layout.fillWidth: true; spacing: 12
        Rectangle {
            implicitWidth: 160; implicitHeight: 24; radius: 5
            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
            border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
            Text { anchors.centerIn: parent; text: parent.parent.keys; color: Colors.primary
                   font { pixelSize: 11; family: "monospace" } }
        }
        Text { text: parent.desc; color: Colors.foreground; font.pixelSize: 12
               Layout.fillWidth: true; wrapMode: Text.WordWrap }
    }

    // Editable shortcut row — used as Repeater delegate; Component gives isolated id scope per instance
    Component {
        id: _srDelegate
        RowLayout {
            id: _srRow
            required property var modelData
            property string _val: ""
            property string _curKeys: modelData.k
            property bool   _done: false
            Layout.fillWidth: true; spacing: 12

            Rectangle {
                visible: !_srRow.modelData.lua
                implicitWidth: 160; implicitHeight: 24; radius: 5
                color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                Text { anchors.centerIn: parent; text: _srRow.modelData.k; color: Colors.primary
                       font { pixelSize: 11; family: "monospace" } }
            }
            Rectangle {
                visible: !!_srRow.modelData.lua
                implicitWidth: 190; implicitHeight: 28; radius: 5
                color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                TextInput {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                    verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                    Component.onCompleted: { text = _srRow.modelData.k; _srRow._val = _srRow.modelData.k }
                    onTextChanged: { _srRow._val = text; _srRow._done = false }
                }
            }
            Text { text: _srRow.modelData.d; color: Colors.foreground; font.pixelSize: 12
                   Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Rectangle {
                visible: !!_srRow.modelData.lua
                implicitWidth: 46; implicitHeight: 28; radius: 6
                color: _srRow._done
                    ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18)
                    : Qt.rgba(Colors.primary.r,   Colors.primary.g,   Colors.primary.b,   0.08)
                border {
                    color: _srRow._done
                        ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6)
                        : Qt.rgba(Colors.primary.r,   Colors.primary.g,   Colors.primary.b,   0.45)
                    width: 1
                }
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: _srRow._done ? "✓" : "Set"
                    color: _srRow._done ? Colors.secondary : Colors.primary
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const newCombo = _srRow._val.trim()
                        const oldCombo = _srRow._curKeys.trim()
                        const lua = _srRow.modelData.lua
                        if (!newCombo || !lua) return
                        Quickshell.execDetached(["hyprctl", "eval",
                            `pcall(hl.unbind, '${oldCombo}'); hl.bind('${newCombo}', ${lua})`])
                        _srRow._curKeys = newCombo
                        _srRow._done = true
                        _srRow.forceActiveFocus()
                    }
                }
            }
        }
    }

    component UnboundRow: RowLayout {
        id: _ubRoot
        property string desc: ""
        property string suggest: ""
        property string luaAction: ""
        property string category: ""
        property string _val: suggest
        property bool   _done: false
        Layout.fillWidth: true; spacing: 8
        visible: !_done

        Text { text: desc; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
        Rectangle {
            implicitWidth: 190; implicitHeight: 28; radius: 5
            color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
            TextInput {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                Component.onCompleted: text = _ubRoot.suggest
                onTextChanged: { _ubRoot._val = text; _ubRoot._done = false }
            }
        }
        Rectangle {
            implicitWidth: 46; implicitHeight: 28; radius: 6
            color: _ubRoot._done
                ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18)
                : Qt.rgba(Colors.primary.r,   Colors.primary.g,   Colors.primary.b,   0.08)
            border {
                color: _ubRoot._done
                    ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6)
                    : Qt.rgba(Colors.primary.r,   Colors.primary.g,   Colors.primary.b,   0.45)
                width: 1
            }
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: _ubRoot._done ? "✓" : "Set"
                color: _ubRoot._done ? Colors.secondary : Colors.primary
                font.pixelSize: 12
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const combo = _ubRoot._val.trim()
                    if (!combo) return
                    Quickshell.execDetached(["hyprctl", "eval",
                        `hl.bind('${combo}', ${_ubRoot.luaAction})`])
                    const cat = _ubRoot.category
                    const entry = { sk: combo, sd: _ubRoot.desc }
                    if      (cat === "apps")  runtimeAppsModel.append(entry)
                    else if (cat === "nav")   runtimeNavModel.append(entry)
                    else if (cat === "move")  runtimeMoveModel.append(entry)
                    else if (cat === "tools") runtimeToolsModel.append(entry)
                    _ubRoot._done = true
                    _ubRoot.forceActiveFocus()
                }
            }
        }
    }

    component ThemedSwitch: Switch {
        id: tSw
        indicator: Rectangle {
            implicitWidth: 38; implicitHeight: 20
            x: tSw.leftPadding; y: (tSw.height - height) / 2; radius: 10
            color: tSw.checked ? Colors.primary : Qt.rgba(1,1,1,0.15)
            Behavior on color { ColorAnimation { duration: 100 } }
            Rectangle {
                x: tSw.checked ? parent.width - width - 2 : 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 8
                color: tSw.checked ? Colors.primaryForeground : Colors.surfaceForeground
                Behavior on x { NumberAnimation { duration: 100 } }
            }
        }
    }

    component ThemedSlider: Slider {
        id: tSlider
        implicitWidth: 160; implicitHeight: 28; from: 0; to: 1; value: 0.5
        background: Rectangle {
            x: tSlider.leftPadding
            y: tSlider.topPadding + tSlider.availableHeight / 2 - height / 2
            width: tSlider.availableWidth; height: 4; radius: 2
            color: Qt.rgba(1,1,1,0.12)
            Rectangle {
                width: tSlider.visualPosition * parent.width
                height: parent.height; radius: parent.radius; color: Colors.primary
            }
        }
        handle: Rectangle {
            x: tSlider.leftPadding + tSlider.visualPosition * (tSlider.availableWidth - width)
            y: tSlider.topPadding + tSlider.availableHeight / 2 - height / 2
            width: 14; height: 14; radius: 7
            color: tSlider.pressed ? Qt.lighter(Colors.primary, 1.2) : Colors.primary
            border { color: Colors.background; width: 2 }
        }
    }

    component ThemedSpinBox: SpinBox {
        id: tSb
        from: 0; to: 100; value: 1
        implicitWidth: 110; implicitHeight: 34
        leftPadding: 28; rightPadding: 28
        editable: true
        background: Rectangle {
            anchors.fill: parent; radius: 6
            color: Qt.rgba(1,1,1,0.07)
            border { color: Qt.rgba(1,1,1,0.15); width: 1 }
        }
        contentItem: TextInput {
            text: tSb.textFromValue(tSb.value, tSb.locale)
            color: Colors.foreground; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            readOnly: !tSb.editable; validator: tSb.validator
            selectByMouse: true
        }
        up.indicator: Rectangle {
            x: tSb.mirrored ? 0 : tSb.width - width
            width: 28; height: tSb.height; radius: 6
            color: tSb.up.pressed ? Qt.rgba(1,1,1,0.18) : tSb.up.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"
            Text { text: "+"; color: Colors.primary; anchors.centerIn: parent; font.pixelSize: 14; font.bold: true }
        }
        down.indicator: Rectangle {
            x: tSb.mirrored ? tSb.width - width : 0
            width: 28; height: tSb.height; radius: 6
            color: tSb.down.pressed ? Qt.rgba(1,1,1,0.18) : tSb.down.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"
            Text { text: "−"; color: Colors.primary; anchors.centerIn: parent; font.pixelSize: 14; font.bold: true }
        }
    }

    component ActionBtn: Rectangle {
        property string lbl: ""; property color col: Colors.primary
        property var action: null
        implicitHeight: 34; radius: 8
        implicitWidth: aBtnLbl.implicitWidth + 24
        color: aBtnMa.containsPress ? Qt.rgba(col.r, col.g, col.b, 0.22)
             : aBtnMa.containsMouse ? Qt.rgba(col.r, col.g, col.b, 0.13) : Qt.rgba(col.r, col.g, col.b, 0.07)
        border { color: Qt.rgba(col.r, col.g, col.b, 0.45); width: 1 }
        Text { id: aBtnLbl; anchors.centerIn: parent; text: lbl; color: col; font.pixelSize: 12 }
        MouseArea {
            id: aBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: if (action) action()
        }
    }

    component ColorSwatch: Rectangle {
        property color swatchColor: "transparent"
        implicitWidth: 20; implicitHeight: 20; radius: 4
        color: swatchColor
        border { color: Qt.rgba(1,1,1,0.2); width: 1 }
    }

    component ColorField: Rectangle {
        id: cfRoot
        property alias text: cfInput.text
        signal edited(string val)
        implicitWidth: 130; implicitHeight: 28; radius: 6
        color: Qt.rgba(1,1,1,0.08); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
        Row {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            Text { text: "#"; color: Colors.surfaceForeground; font { pixelSize: 12; family: "monospace" } }
            TextInput {
                id: cfInput; width: 88; color: Colors.foreground
                font { pixelSize: 12; family: "monospace" }
                maximumLength: 8
                onTextEdited: cfRoot.edited(text)
            }
        }
    }

    component ColorPicker: Popup {
        id: cp
        property string hex: "90cef4"
        property real hue: 0.0
        property real sat: 1.0
        property real val: 1.0
        property bool syncing: false
        signal pickDone(string newHex)

        function hsvToHex(h, s, v) {
            const i = Math.floor(h * 6) % 6
            const f = h * 6 - Math.floor(h * 6)
            const p = v*(1-s), q = v*(1-f*s), t = v*(1-(1-f)*s)
            const rgb = [[v,t,p],[q,v,p],[p,v,t],[p,q,v],[t,p,v],[v,p,q]][i]
            return rgb.map(c => ('0'+Math.round(c*255).toString(16)).slice(-2)).join('')
        }

        function hexToHsv(h6) {
            if (h6.length !== 6) return
            const r = parseInt(h6.slice(0,2),16)/255
            const g = parseInt(h6.slice(2,4),16)/255
            const b = parseInt(h6.slice(4,6),16)/255
            const M = Math.max(r,g,b), m = Math.min(r,g,b), d = M-m
            syncing = true
            val = M
            sat = M > 0 ? d/M : 0
            if (d > 0) {
                let hh = M===r ? ((g-b)/d)%6 : M===g ? (b-r)/d+2 : (r-g)/d+4
                hue = ((hh/6)%1+1)%1
            }
            syncing = false
            svCanvas.requestPaint()
        }

        onHueChanged: { if (!syncing) { syncing=true; hex=hsvToHex(hue,sat,val); syncing=false; svCanvas.requestPaint() } }
        onSatChanged: { if (!syncing) { syncing=true; hex=hsvToHex(hue,sat,val); syncing=false } }
        onValChanged: { if (!syncing) { syncing=true; hex=hsvToHex(hue,sat,val); syncing=false } }
        onHexChanged: { if (!syncing) hexToHsv(hex) }
        onOpened:     { if (hex.length === 6) hexToHsv(hex) }

        padding: 12; modal: false; dim: false; width: 240

        background: Rectangle {
            color: Colors.surface; radius: 10
            border { color: Qt.rgba(1,1,1,0.25); width: 1 }
        }

        contentItem: ColumnLayout {
            spacing: 8

            // Saturation / Value square
            Rectangle {
                Layout.fillWidth: true; height: 160; radius: 6; clip: true
                Canvas {
                    id: svCanvas
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d")
                        const hc = Qt.hsva(cp.hue, 1, 1, 1).toString()
                        const sg = ctx.createLinearGradient(0, 0, width, 0)
                        sg.addColorStop(0, "white"); sg.addColorStop(1, hc)
                        ctx.fillStyle = sg; ctx.fillRect(0, 0, width, height)
                        const vg = ctx.createLinearGradient(0, 0, 0, height)
                        vg.addColorStop(0, "rgba(0,0,0,0)"); vg.addColorStop(1, "rgba(0,0,0,1)")
                        ctx.fillStyle = vg; ctx.fillRect(0, 0, width, height)
                    }
                }
                // crosshair
                Rectangle {
                    x: cp.sat * parent.width - width / 2
                    y: (1 - cp.val) * parent.height - height / 2
                    width: 14; height: 14; radius: 7
                    color: "transparent"; border { color: "white"; width: 2 }
                }
                MouseArea {
                    anchors.fill: parent; preventStealing: true
                    function pick(x, y) {
                        cp.sat = Math.max(0, Math.min(1, x / width))
                        cp.val = Math.max(0, Math.min(1, 1 - y / height))
                    }
                    onPressed: mouse => pick(mouse.x, mouse.y)
                    onPositionChanged: mouse => { if (pressed) pick(mouse.x, mouse.y) }
                }
            }

            // Hue slider
            Item {
                Layout.fillWidth: true; height: 18
                Rectangle {
                    anchors.fill: parent; radius: 9
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.000; color: "#FF0000" }
                        GradientStop { position: 0.167; color: "#FFFF00" }
                        GradientStop { position: 0.333; color: "#00FF00" }
                        GradientStop { position: 0.500; color: "#00FFFF" }
                        GradientStop { position: 0.667; color: "#0000FF" }
                        GradientStop { position: 0.833; color: "#FF00FF" }
                        GradientStop { position: 1.000; color: "#FF0000" }
                    }
                }
                // handle
                Rectangle {
                    x: cp.hue * parent.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16; radius: 8
                    color: "transparent"; border { color: "white"; width: 2 }
                }
                MouseArea {
                    anchors.fill: parent; preventStealing: true
                    function pick(x) { cp.hue = Math.max(0, Math.min(0.9999, x / width)) }
                    onPressed: mouse => pick(mouse.x)
                    onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
                }
            }

            // Preview + hex field
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    width: 36; height: 28; radius: 6
                    color: cp.hex.length === 6 ? "#" + cp.hex : Colors.surface
                    border { color: Qt.rgba(1,1,1,0.2); width: 1 }
                }
                ColorField {
                    Layout.fillWidth: true; text: cp.hex
                    onEdited: v => { if (v.length === 6) cp.hex = v }
                }
            }

            ActionBtn { Layout.fillWidth: true; lbl: "Select"; action: () => { cp.pickDone(cp.hex); cp.close() } }
        }
    }

    // Shared picker instance — positioned before calling open()
    ColorPicker {
        id: sharedPicker
        parent: Overlay.overlay
        property var callback: null
        onPickDone: (h) => { if (callback) callback(h) }
    }

    function openPicker(nearItem, initialHex, cb) {
        sharedPicker.hex = initialHex.substring(0, 6)
        sharedPicker.callback = cb
        const gpt = nearItem.mapToGlobal(0, nearItem.height + 6)
        const lpt = sharedPicker.parent.mapFromGlobal(gpt.x, gpt.y)
        sharedPicker.x = Math.min(Math.max(4, lpt.x), sharedPicker.parent.width  - sharedPicker.width  - 4)
        sharedPicker.y = Math.min(Math.max(4, lpt.y), sharedPicker.parent.height - sharedPicker.height - 4)
        sharedPicker.open()
    }

    // ── Layout ────────────────────────────────────────────────────

    RowLayout {
        anchors { fill: parent; margins: 8 }
        spacing: 8

        // Nav rail
        Rectangle {
            Layout.fillHeight: true; implicitWidth: 160
            color: Qt.rgba(1,1,1,0.03); radius: 10
            border { color: Qt.rgba(1,1,1,0.08); width: 1 }
            ColumnLayout {
                anchors { fill: parent; margins: 10 }
                spacing: 4
                Item { Layout.preferredHeight: 4 }
                Text {
                    text: "Settings"; Layout.leftMargin: 4
                    color: Colors.primary
                    font { pixelSize: 14; bold: true }
                }
                Rectangle {
                    height: 1; Layout.fillWidth: true; color: Qt.rgba(1,1,1,0.1)
                    Layout.topMargin: 4; Layout.bottomMargin: 4
                }
                NavBtn { idx: 0; lbl: "Quick";      ico: "⚡" }
                NavBtn { idx: 1; lbl: "General";    ico: "📋" }
                NavBtn { idx: 2; lbl: "Bar";        ico: "━" }
                NavBtn { idx: 3; lbl: "Display";    ico: "🖥" }
                NavBtn { idx: 4; lbl: "Interface";  ico: "⚙" }
                NavBtn { idx: 5; lbl: "Liquidglass";ico: "◎" }
                NavBtn { idx: 6; lbl: "Terminal";   ico: "⌨" }
                NavBtn { idx: 7; lbl: "About";      ico: "ℹ" }
                NavBtn { idx: 8; lbl: "Shortcuts";  ico: "⌨" }
                Item { Layout.fillHeight: true }
            }
        }

        // Content pane
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            color: Qt.rgba(1,1,1,0.03); radius: 10
            border { color: Qt.rgba(1,1,1,0.08); width: 1 }
            clip: true

            StackLayout {
                anchors.fill: parent
                currentIndex: root.currentPage

                // ═══════════════════════════════════════════════════
                // PAGE 0 — Quick
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Wallpaper & Colors"; i: "🎨" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                Rectangle {
                                    implicitWidth: 300; implicitHeight: 180; radius: 8; clip: true
                                    color: Qt.rgba(1,1,1,0.06)
                                    Image {
                                        id: wallImg; anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                                        source: "file:///home/sam/.cache/wallpaper-picker/wallpaper_DP-2.png"
                                        cache: false
                                    }
                                    Text {
                                        visible: wallImg.status !== Image.Ready
                                        anchors.centerIn: parent; text: "No preview"
                                        color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.3)
                                        font.pixelSize: 11
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    ActionBtn {
                                        Layout.fillWidth: true; lbl: "Pick Wallpaper"
                                        action: () => Quickshell.execDetached(["waypaper"])
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Dark/Light Mode"; font.pixelSize: 12; Layout.fillWidth: true
                                               color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4) }
                                        StubTag {}
                                        ThemedSwitch { enabled: false; checked: true; opacity: 0.3 }
                                    }
                                }
                            }
                            Sep {}
                            Text { text: "Color Scheme (affects GTK, fuzzel, Hyprland borders)"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                            Flow {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: [
                                        { label: "Tonal Spot",  type: "scheme-tonal-spot" },
                                        { label: "Content",     type: "scheme-content" },
                                        { label: "Expressive",  type: "scheme-expressive" },
                                        { label: "Fidelity",    type: "scheme-fidelity" },
                                        { label: "Fruit Salad", type: "scheme-fruit-salad" },
                                        { label: "Monochrome",  type: "scheme-monochrome" },
                                        { label: "Neutral",     type: "scheme-neutral" },
                                        { label: "Rainbow",     type: "scheme-rainbow" },
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitHeight: 30; radius: 6; implicitWidth: schLbl.implicitWidth + 20
                                        color: sma.containsPress ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.22)
                                             : sma.containsMouse ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.12)
                                             : Qt.rgba(1,1,1,0.05)
                                        border { color: Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.35); width: 1 }
                                        Text { id: schLbl; anchors.centerIn: parent; text: modelData.label; color: Colors.secondary; font.pixelSize: 11 }
                                        MouseArea {
                                            id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const wall = wallpaperReader.path || "/usr/share/backgrounds/sway/Sway_Wallpaper_Blue_1920x1080.png"
                                                Quickshell.execDetached(["bash", "-c",
                                                    `matugen image '${wall}' --mode dark --type ${modelData.type} && hyprctl reload`])
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Bar colors come from ricemood (recolor.sh) — pick a wallpaper via waypaper to update them."
                                color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.5)
                                font.pixelSize: 10; wrapMode: Text.WordWrap
                            }
                        }

                        Hdr { t: "Bar & Screen"; i: "━" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Bar Position"; font.pixelSize: 12; Layout.fillWidth: true
                                       color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4) }
                                StubTag {}
                                Flow { spacing: 4
                                    Repeater {
                                        model: ["Top", "Left", "Bottom", "Right"]
                                        delegate: Rectangle {
                                            required property string modelData
                                            implicitWidth: posLbl.implicitWidth + 16; implicitHeight: 26; radius: 5
                                            color: Qt.rgba(1,1,1,0.05); border { color: Qt.rgba(1,1,1,0.12); width: 1 }
                                            Text { id: posLbl; anchors.centerIn: parent; text: modelData; color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.35); font.pixelSize: 11 }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Screen Rounding"; font.pixelSize: 12; Layout.fillWidth: true
                                       color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4) }
                                StubTag {}
                                ThemedSwitch { enabled: false; checked: false; opacity: 0.3 }
                            }
                        }
                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 1 — General
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Audio"; i: "🔊" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Volume"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider {
                                    id: volumeSlider; from: 0; to: 1.5; stepSize: 0.01; value: 0.5
                                    onMoved: {
                                        root.currentVolume = value
                                        Quickshell.execDetached(["bash", "-c", `wpctl set-volume @DEFAULT_AUDIO_SINK@ ${value.toFixed(2)}`])
                                    }
                                }
                                Text {
                                    text: Math.round(root.currentVolume * 100) + "%"
                                    color: root.currentVolume > 1.0 ? Colors.errorColor : Colors.primary
                                    font.pixelSize: 11; width: 38
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Mute"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch {
                                    id: muteSwitch
                                    checked: root.currentMuted
                                    onToggled: {
                                        root.currentMuted = checked
                                        Quickshell.execDetached(["bash", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"])
                                    }
                                }
                            }
                        }

                        Hdr { t: "Clock Format"; i: "🕐" }

                        // clock prefs tracked here so delegates can reach them by id
                        QtObject {
                            id: clockPrefs
                            property string base: "ddd dd MMM  hh:mm"
                            property bool showSecs: false
                            property string full: base.replace("hh:mm", showSecs ? "hh:mm:ss" : "hh:mm")
                                                      .replace("HH:mm", showSecs ? "HH:mm:ss" : "HH:mm")
                            function apply() {
                                Quickshell.execDetached(["bash", "-c", `printf '%s' '${full}' > ~/.config/quickshell/clock_format`])
                            }
                        }

                        Card {
                            Text {
                                text: "Preview: " + Qt.formatDateTime(new Date(), clockPrefs.full)
                                color: Colors.primary; font { pixelSize: 13; bold: true }
                            }
                            Sep {}
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Hour Style"; color: Colors.foreground; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Flow { spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "24h",        base: "ddd dd MMM  HH:mm" },
                                            { label: "12h AM/PM",  base: "ddd dd MMM  hh:mm AP" },
                                            { label: "24h (bare)", base: "HH:mm" },
                                            { label: "12h (bare)", base: "hh:mm AP" },
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            implicitWidth: fmtOptLbl.implicitWidth + 16; implicitHeight: 28; radius: 6
                                            color: clockPrefs.base === modelData.base ? Colors.primary
                                                 : fmtOptMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(1,1,1,0.05)
                                            border { color: clockPrefs.base === modelData.base ? "transparent" : Qt.rgba(1,1,1,0.15); width: 1 }
                                            Text {
                                                id: fmtOptLbl; anchors.centerIn: parent; text: modelData.label
                                                color: clockPrefs.base === modelData.base ? Colors.primaryForeground : Colors.foreground
                                                font.pixelSize: 11
                                            }
                                            MouseArea {
                                                id: fmtOptMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { clockPrefs.base = modelData.base; clockPrefs.apply() }
                                            }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Show Seconds"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch {
                                    checked: clockPrefs.showSecs
                                    onToggled: { clockPrefs.showSecs = checked; clockPrefs.apply() }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Bar clock updates live — no restart needed."
                                color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.5)
                                font.pixelSize: 10
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 2 — Bar
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Bar Style"; i: "━" }
                        Text {
                            Layout.fillWidth: true
                            text: "Click Apply to Bar to save settings. The bar will restart automatically to pick up changes."
                            color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.6)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Style"; color: Colors.foreground; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                Flow { spacing: 4
                                    Repeater {
                                        model: [{ label: "Pill", pill: true }, { label: "Traditional", pill: false }]
                                        delegate: Rectangle {
                                            required property var modelData
                                            implicitWidth: _styleLbl.implicitWidth + 16; implicitHeight: 28; radius: 6
                                            color: root.barPillMode === modelData.pill
                                                ? Colors.primary
                                                : _styleMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(1,1,1,0.05)
                                            border { color: root.barPillMode === modelData.pill ? "transparent" : Qt.rgba(1,1,1,0.15); width: 1 }
                                            Text {
                                                id: _styleLbl; anchors.centerIn: parent; text: modelData.label
                                                color: root.barPillMode === modelData.pill ? Colors.primaryForeground : Colors.foreground
                                                font.pixelSize: 11
                                            }
                                            MouseArea {
                                                id: _styleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.barPillMode = modelData.pill
                                            }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Opacity"; color: Colors.foreground; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                                ThemedSlider {
                                    id: barOpacitySlider; from: 0.05; to: 1.0; stepSize: 0.01
                                    value: root.barOpacity
                                    onMoved: root.barOpacity = value
                                }
                                Text { text: Math.round(root.barOpacity * 100) + "%"; color: Colors.primary; font.pixelSize: 11; width: 36 }
                            }
                            Sep {}
                            Text { text: "Widgets"; color: Colors.surfaceForeground; font { pixelSize: 11; bold: true } }
                            GridLayout {
                                Layout.fillWidth: true; columns: 2; columnSpacing: 16; rowSpacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Workspaces"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowWorkspaces; onToggled: root.barShowWorkspaces = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Window Title"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowWindowTitle; onToggled: root.barShowWindowTitle = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Clock"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowClock; onToggled: root.barShowClock = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "System Tray"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowSystemTray; onToggled: root.barShowSystemTray = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Volume"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowVolume; onToggled: root.barShowVolume = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Network"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowNetwork; onToggled: root.barShowNetwork = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "CPU Usage"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowCpu; onToggled: root.barShowCpu = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "GPU Usage"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowGpu; onToggled: root.barShowGpu = checked }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Memory"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                    ThemedSwitch { checked: root.barShowMem; onToggled: root.barShowMem = checked }
                                }
                            }
                            Sep {}
                            ActionBtn {
                                lbl: "Apply to Bar"; col: Colors.primary
                                action: () => root.applyBarConfig()
                            }
                        }

                        Hdr { t: "Bar Colors (Colors.qml)"; i: "🎨" }
                        Text {
                            Layout.fillWidth: true
                            text: "Edit hex values then click Apply. Rewrites Colors.qml in both profile and live, then restarts the bar. Color swatches update as you type."
                            color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.6)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }
                        Card {
                            Repeater {
                                model: barColorModel
                                delegate: RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    ColorSwatch {
                                        id: barSwatch
                                        implicitWidth: 28; implicitHeight: 24
                                        swatchColor: model.hex.length === 6 ? "#" + model.hex : Colors.surface
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openPicker(barSwatch, model.hex,
                                                (h) => barColorModel.setProperty(index, "hex", h))
                                        }
                                    }
                                    Text {
                                        text: model.label; color: Colors.foreground
                                        font.pixelSize: 12; Layout.preferredWidth: 90
                                    }
                                    Item { Layout.fillWidth: true }
                                    ColorField {
                                        text: model.hex
                                        onEdited: val => barColorModel.setProperty(index, "hex", val)
                                    }
                                }
                            }
                            Sep {}
                            Text {
                                Layout.fillWidth: true
                                text: "⚠  Swatches here reflect values at launch. Reopen Settings after applying to see updated colours."
                                color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.7)
                                font.pixelSize: 10; wrapMode: Text.WordWrap
                            }
                            Sep {}
                            ActionBtn {
                                lbl: "Apply + Restart Bar"; col: Colors.primary
                                action: () => root.applyBarColors()
                            }
                        }

                        Hdr { t: "Hyprland Border Colors (colors.lua)"; i: "⬜" }
                        Text {
                            Layout.fillWidth: true
                            text: "RRGGBBAA — last two digits are opacity (ee = ~93%, aa = ~67%). Active border is a A→B gradient at 45°. Picker sets RGB; alpha is preserved."
                            color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.6)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ColorSwatch {
                                    id: ba1Swatch; implicitWidth: 28; implicitHeight: 24
                                    swatchColor: root.borderActive1.length >= 6 ? "#" + root.borderActive1.substring(0,6) : Colors.surface
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openPicker(ba1Swatch, root.borderActive1.substring(0,6),
                                            (h) => root.borderActive1 = h + root.borderActive1.substring(6))
                                    }
                                }
                                Text { text: "Active Border A"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ColorField {
                                    text: root.borderActive1
                                    onEdited: val => root.borderActive1 = val
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ColorSwatch {
                                    id: ba2Swatch; implicitWidth: 28; implicitHeight: 24
                                    swatchColor: root.borderActive2.length >= 6 ? "#" + root.borderActive2.substring(0,6) : Colors.surface
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openPicker(ba2Swatch, root.borderActive2.substring(0,6),
                                            (h) => root.borderActive2 = h + root.borderActive2.substring(6))
                                    }
                                }
                                Text { text: "Active Border B"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ColorField {
                                    text: root.borderActive2
                                    onEdited: val => root.borderActive2 = val
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                ColorSwatch {
                                    id: iaSwatch; implicitWidth: 28; implicitHeight: 24
                                    swatchColor: root.borderInactive.length >= 6 ? "#" + root.borderInactive.substring(0,6) : Colors.surface
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openPicker(iaSwatch, root.borderInactive.substring(0,6),
                                            (h) => root.borderInactive = h + root.borderInactive.substring(6))
                                    }
                                }
                                Text { text: "Inactive Border"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ColorField {
                                    text: root.borderInactive
                                    onEdited: val => root.borderInactive = val
                                }
                            }
                            Sep {}
                            ActionBtn {
                                lbl: "Apply Live + Save"; col: Colors.secondary
                                action: () => root.applyBorderColors()
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 3 — Display
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Monitors"; i: "🖥" }
                        Text {
                            Layout.fillWidth: true
                            text: "Changes apply instantly via hl.monitor(). A brief screen flicker on scale change is normal."
                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.8)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }

                        Repeater {
                            model: monitorModel
                            delegate: Card {
                                required property string name
                                required property int    monWidth
                                required property int    monHeight
                                required property int    hz
                                required property int    posX
                                required property int    posY
                                required property real   monScale
                                required property string hzList
                                required property int    index
                                property  int    monIdx: index

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: name; color: Colors.primary; font { pixelSize: 13; bold: true } }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: monWidth + "×" + monHeight + "  pos " + posX + "," + posY
                                        color: Colors.surfaceForeground; font.pixelSize: 11
                                    }
                                }
                                Sep {}
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Refresh Rate"; color: Colors.foreground; font.pixelSize: 12 }
                                    Item { Layout.fillWidth: true }
                                    Flow { spacing: 4
                                        Repeater {
                                            model: hzList.split(",")
                                            delegate: Rectangle {
                                                required property string modelData
                                                implicitWidth: _hzLbl.implicitWidth + 16; implicitHeight: 28; radius: 6
                                                color: parseInt(modelData) === hz
                                                    ? Colors.primary
                                                    : _hzMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                                                    : Qt.rgba(1,1,1,0.05)
                                                border { color: parseInt(modelData) === hz ? "transparent" : Qt.rgba(1,1,1,0.15); width: 1 }
                                                Text { id: _hzLbl; anchors.centerIn: parent
                                                       text: modelData + "Hz"
                                                       color: parseInt(modelData) === hz ? Colors.primaryForeground : Colors.foreground
                                                       font.pixelSize: 11 }
                                                MouseArea {
                                                    id: _hzMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        const newHz = parseInt(modelData)
                                                        monitorModel.setProperty(monIdx, "hz", newHz)
                                                        root.applyMonitor(monIdx, newHz, undefined)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Scale"; color: Colors.foreground; font.pixelSize: 12 }
                                    Item { Layout.fillWidth: true }
                                    Flow { spacing: 4
                                        Repeater {
                                            model: ["0.5", "0.75", "1.0", "1.25", "1.5", "2.0"]
                                            delegate: Rectangle {
                                                required property string modelData
                                                property real sv: parseFloat(modelData)
                                                implicitWidth: _scLbl.implicitWidth + 16; implicitHeight: 28; radius: 6
                                                color: Math.abs(sv - monScale) < 0.01
                                                    ? Colors.secondary
                                                    : _scMa.containsMouse ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.15)
                                                    : Qt.rgba(1,1,1,0.05)
                                                border { color: Math.abs(sv - monScale) < 0.01 ? "transparent" : Qt.rgba(1,1,1,0.15); width: 1 }
                                                Text { id: _scLbl; anchors.centerIn: parent
                                                       text: modelData + "×"
                                                       color: Math.abs(sv - monScale) < 0.01 ? Colors.primaryForeground : Colors.foreground
                                                       font.pixelSize: 11 }
                                                MouseArea {
                                                    id: _scMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        monitorModel.setProperty(monIdx, "monScale", sv)
                                                        root.applyMonitor(monIdx, undefined, sv)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Hdr { t: "Adaptive Sync (VRR)"; i: "⚡" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "VRR Mode"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                Flow { spacing: 6
                                    Repeater {
                                        model: [
                                            { label: "Off",        val: 0 },
                                            { label: "On",         val: 1 },
                                            { label: "Fullscreen", val: 2 },
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            implicitWidth: _vrrLbl.implicitWidth + 16; implicitHeight: 28; radius: 6
                                            color: root.hyprVRR === modelData.val ? Colors.primary
                                                 : _vrrMa.containsMouse ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15)
                                                 : Qt.rgba(1,1,1,0.05)
                                            border { color: root.hyprVRR === modelData.val ? "transparent" : Qt.rgba(1,1,1,0.15); width: 1 }
                                            Text { id: _vrrLbl; anchors.centerIn: parent; text: modelData.label
                                                   color: root.hyprVRR === modelData.val ? Colors.primaryForeground : Colors.foreground
                                                   font.pixelSize: 11 }
                                            MouseArea {
                                                id: _vrrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.hyprVRR = modelData.val
                                                    Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({misc={vrr=${modelData.val}}})" `])
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Fullscreen = VRR only when a game or app is fullscreen."
                                color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.5)
                                font.pixelSize: 10
                            }
                        }

                        Hdr { t: "Night Light"; i: "🌙" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Enabled"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch {
                                    checked: root.sunsetEnabled
                                    onToggled: {
                                        root.sunsetEnabled = checked
                                        if (checked)
                                            Quickshell.execDetached(["bash", "-c", `hyprsunset -t ${root.sunsetTemp} & disown`])
                                        else
                                            Quickshell.execDetached(["bash", "-c", "pkill hyprsunset 2>/dev/null; true"])
                                    }
                                }
                            }
                            Sep {}
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Temperature"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider {
                                    id: sunsetSlider; from: 1000; to: 6500; value: root.sunsetTemp; stepSize: 100
                                    onMoved: {
                                        root.sunsetTemp = Math.round(value)
                                        if (root.sunsetEnabled)
                                            Quickshell.execDetached(["bash", "-c", `pkill hyprsunset 2>/dev/null; hyprsunset -t ${root.sunsetTemp} & disown`])
                                    }
                                }
                                Text { text: Math.round(sunsetSlider.value) + "K"; color: Colors.primary; font.pixelSize: 11; width: 48 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "2700K = candle  ·  4000K = neutral  ·  6500K = daylight"
                                color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.5)
                                font.pixelSize: 10
                            }
                        }

                        Hdr { t: "Cursor"; i: "🖱" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Hide Timeout"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { from: 0; to: 60; value: 0
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({cursor={inactive_timeout=${value}}})" `]) }
                                Text { text: "s  (0 = never)"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                            }
                        }

                        Hdr { t: "Power & Sleep"; i: "💤" }
                        Card {
                            GridLayout {
                                Layout.fillWidth: true; columns: 4; rowSpacing: 10; columnSpacing: 12
                                Text { text: "Lock Screen";    color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: idleLockSb;    from: 1; to: 120; value: root.idleLockMins; enabled: root.idleLockEnabled; opacity: root.idleLockEnabled ? 1 : 0.35 }
                                Text { text: "min"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                                ThemedSwitch { checked: root.idleLockEnabled;    onToggled: root.idleLockEnabled    = checked }
                                Text { text: "Display Off";    color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: idleDisplaySb; from: 1; to: 120; value: root.idleDisplayMins; enabled: root.idleDisplayEnabled; opacity: root.idleDisplayEnabled ? 1 : 0.35 }
                                Text { text: "min"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                                ThemedSwitch { checked: root.idleDisplayEnabled; onToggled: root.idleDisplayEnabled = checked }
                                Text { text: "System Suspend"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: idleSleepSb;   from: 1; to: 360; value: root.idleSleepMins;   enabled: root.idleSleepEnabled;   opacity: root.idleSleepEnabled   ? 1 : 0.35 }
                                Text { text: "min"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                                ThemedSwitch { checked: root.idleSleepEnabled;   onToggled: root.idleSleepEnabled   = checked }
                            }
                            Sep {}
                            ActionBtn {
                                lbl: "Apply"
                                action: () => {
                                    const lock = root.idleLockEnabled    ? idleLockSb.value    * 60 : 0
                                    const disp = root.idleDisplayEnabled ? idleDisplaySb.value * 60 : 0
                                    const susp = root.idleSleepEnabled   ? idleSleepSb.value   * 60 : 0
                                    Quickshell.execDetached(["bash", "-c",
                                        `/home/sam/.config/quickshell/hypridle-set.sh ${lock} ${disp} ${susp}`])
                                }
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 4 — Interface (Hyprland)
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Interface"; i: "⚙" }
                        Text {
                            Layout.fillWidth: true
                            text: "Values are read from Hyprland on startup and applied live. Changes reset when Hyprland restarts — update hyprland.lua to persist."
                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.8)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }

                        Hdr { t: "Gaps & Borders"; i: "⬜" }
                        Card {
                            GridLayout {
                                Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 24
                                Text { text: "Gaps In";         color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: gapsIn; from: 0; to: 30; value: root.hyprGapsIn
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({general={gaps_in=${value}}})" `]) }
                                Text { text: "Gaps Out";        color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: gapsOut; from: 0; to: 60; value: root.hyprGapsOut
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({general={gaps_out=${value}}})" `]) }
                                Text { text: "Border Size";     color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: borderSz; from: 0; to: 10; value: root.hyprBorderSz
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({general={border_size=${value}}})" `]) }
                                Text { text: "Corner Rounding"; color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: rounding; from: 0; to: 30; value: root.hyprRounding
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={rounding=${value}}})" `]) }
                            }
                        }

                        Hdr { t: "Window Opacity"; i: "◑" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Active Window"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: activeOp; from: 0.5; to: 1.0; value: root.hyprActiveOp; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={active_opacity=${value.toFixed(2)}}})" `]) }
                                Text { text: activeOp.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Inactive Windows"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: inactiveOp; from: 0.5; to: 1.0; value: root.hyprInactiveOp; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={inactive_opacity=${value.toFixed(2)}}})" `]) }
                                Text { text: inactiveOp.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                        }

                        Hdr { t: "Blur"; i: "💧" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Enabled"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch { checked: root.hyprBlurEnabled
                                    onToggled: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={blur={enabled=${checked}}}})" `]) }
                            }
                            Sep {}
                            GridLayout {
                                Layout.fillWidth: true; columns: 2; rowSpacing: 10; columnSpacing: 24
                                Text { text: "Blur Size";   color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: blurSz; from: 1; to: 20; value: root.hyprBlurSz
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={blur={size=${value}}}})" `]) }
                                Text { text: "Blur Passes"; color: Colors.foreground; font.pixelSize: 12 }
                                ThemedSpinBox { id: blurPasses; from: 1; to: 10; value: root.hyprBlurPasses
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({decoration={blur={passes=${value}}}})" `]) }
                            }
                        }

                        Hdr { t: "Animations"; i: "✨" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Enabled"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch { checked: root.hyprAnimEnabled
                                    onToggled: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({animations={enabled=${checked}}})" `]) }
                            }
                        }

                        Hdr { t: "Overview"; i: "🗂" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Enable"; font.pixelSize: 12; Layout.fillWidth: true
                                       color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4) }
                                StubTag {}
                                ThemedSwitch { enabled: false; checked: false; opacity: 0.3 }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Overview/expose is not implemented in this rice."
                                color: Qt.rgba(Colors.surfaceForeground.r, Colors.surfaceForeground.g, Colors.surfaceForeground.b, 0.5)
                                font.pixelSize: 10; wrapMode: Text.WordWrap
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 5 — Liquidglass
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Liquidglass"; i: "◎" }
                        Text {
                            Layout.fillWidth: true
                            text: "⚠  Changes apply live but reset on Hyprland restart. Update the liquidglass block in hyprland.lua to persist."
                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.8)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }

                        Hdr { t: "General"; i: "◈" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Enabled"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSwitch { checked: true
                                    onToggled: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={enabled=${checked ? 1 : 0}}}})" `]) }
                            }
                            Sep {}
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Window Opacity"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: wOpacity; from: 0.5; to: 1.0; value: 0.90; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={window_opacity=${value.toFixed(2)}}}})" `]) }
                                Text { text: wOpacity.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Glass Opacity"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: gOpacity; from: 0.0; to: 1.0; value: 0.78; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={glass_opacity=${value.toFixed(2)}}}})" `]) }
                                Text { text: gOpacity.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Layer Corner Radius"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: layerRadius; from: 0; to: 40; value: 12
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={layer_corner_radius=${value}}}})" `]) }
                            }
                        }

                        Hdr { t: "Blur"; i: "💧" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Blur Strength"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: blurStr; from: 0.0; to: 1.0; value: 0.32; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={blur_strength=${value.toFixed(2)}}}})" `]) }
                                Text { text: blurStr.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Blur Iterations"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: blurIter; from: 1; to: 8; value: 2
                                    onValueModified: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={blur_iterations=${value}}}})" `]) }
                            }
                        }

                        Hdr { t: "Optics"; i: "🔭" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Refraction Strength"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: refrStr; from: 0.5; to: 3.0; value: 1.15; stepSize: 0.05
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={refraction_strength=${value.toFixed(2)}}}})" `]) }
                                Text { text: refrStr.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Chromatic Aberration"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: chromAb; from: 0.0; to: 2.0; value: 0.90; stepSize: 0.05
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={chromatic_aberration=${value.toFixed(2)}}}})" `]) }
                                Text { text: chromAb.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Lens Distortion"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: lensDist; from: 0.5; to: 3.0; value: 1.15; stepSize: 0.05
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={lens_distortion=${value.toFixed(2)}}}})" `]) }
                                Text { text: lensDist.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Fresnel Strength"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: fresnelStr; from: 0.0; to: 1.0; value: 0.46; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={fresnel_strength=${value.toFixed(2)}}}})" `]) }
                                Text { text: fresnelStr.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Specular Strength"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: specStr; from: 0.0; to: 1.0; value: 0.38; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={specular_strength=${value.toFixed(2)}}}})" `]) }
                                Text { text: specStr.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Edge Thickness"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: edgeThick; from: 0.0; to: 0.2; value: 0.040; stepSize: 0.005
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={edge_thickness=${value.toFixed(3)}}}})" `]) }
                                Text { text: edgeThick.value.toFixed(3); color: Colors.primary; font.pixelSize: 11; width: 38 }
                            }
                        }

                        Hdr { t: "Color Grading"; i: "🎞" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Brightness"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: brightness; from: 0.5; to: 1.5; value: 0.88; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={brightness=${value.toFixed(2)}}}})" `]) }
                                Text { text: brightness.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Contrast"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: contrast; from: 0.5; to: 1.5; value: 1.16; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={contrast=${value.toFixed(2)}}}})" `]) }
                                Text { text: contrast.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Saturation"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: saturation; from: 0.5; to: 2.0; value: 1.14; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={saturation=${value.toFixed(2)}}}})" `]) }
                                Text { text: saturation.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Vibrancy"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: vibrancy; from: 0.0; to: 1.0; value: 0.32; stepSize: 0.01
                                    onMoved: Quickshell.execDetached(["bash", "-c", `hyprctl eval "hl.config({plugin={liquidglass={vibrancy=${value.toFixed(2)}}}})" `]) }
                                Text { text: vibrancy.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                        }

                        Hdr { t: "Rules"; i: "📋" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Exclude Classes"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                TextField {
                                    implicitWidth: 200; text: "!nemo,kitty"
                                    color: Colors.foreground; font.pixelSize: 12
                                    background: Rectangle {
                                        radius: 6; color: Qt.rgba(1,1,1,0.08)
                                        border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                    }
                                    onEditingFinished: Quickshell.execDetached(["bash", "-c",
                                        `hyprctl eval "hl.config({plugin={liquidglass={exclude_classes='${text}'}}})" `])
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Tint Color"; font.pixelSize: 12; Layout.fillWidth: true
                                       color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.4) }
                                StubTag {}
                                Rectangle {
                                    implicitWidth: 90; implicitHeight: 28; radius: 6
                                    color: Qt.rgba(1,1,1,0.06); border { color: Qt.rgba(1,1,1,0.12); width: 1 }
                                    Text { anchors.centerIn: parent; text: "#b8d8ff00"
                                           color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.35); font.pixelSize: 11 }
                                }
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 6 — Terminal
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Terminal (Kitty)"; i: "⌨" }
                        Text {
                            Layout.fillWidth: true
                            text: "Changes write to ~/.config/kitty/kitty.conf and signal kitty to reload. Click Apply to commit."
                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.8)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }

                        Hdr { t: "Appearance"; i: "🖌" }
                        Card {
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Background Opacity"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSlider { id: kittyOp; from: 0.1; to: 1.0; value: 0.85; stepSize: 0.01 }
                                Text { text: kittyOp.value.toFixed(2); color: Colors.primary; font.pixelSize: 11; width: 34 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Font Size"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                ThemedSpinBox { id: kittyFontSz; from: 8; to: 24; value: 12 }
                                Text { text: "pt"; color: Colors.surfaceForeground; font.pixelSize: 11 }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Font Family"; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true }
                                TextField {
                                    id: kittyFont; implicitWidth: 200; text: "monospace"
                                    color: Colors.foreground; font.pixelSize: 12
                                    background: Rectangle {
                                        radius: 6; color: Qt.rgba(1,1,1,0.08)
                                        border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                    }
                                }
                            }
                            Sep {}
                            ActionBtn {
                                lbl: "Apply"
                                action: () => {
                                    const op = kittyOp.value.toFixed(2)
                                    const sz = kittyFontSz.value + ".0"
                                    const fam = kittyFont.text.replace(/'/g, "'\\''")
                                    Quickshell.execDetached(["bash", "-c",
                                        `sed -i 's/^background_opacity .*/background_opacity ${op}/' ~/.config/kitty/kitty.conf && ` +
                                        `sed -i 's/^font_size .*/font_size ${sz}/' ~/.config/kitty/kitty.conf && ` +
                                        `sed -i 's/^font_family .*/font_family      ${fam}/' ~/.config/kitty/kitty.conf && ` +
                                        `pkill -SIGUSR1 kitty 2>/dev/null || true`])
                                }
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 7 — About
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "About"; i: "ℹ" }
                        Card {
                            Text { text: "Default Rice"; color: Colors.primary; font { pixelSize: 18; bold: true } }
                            Text {
                                text: "Quickshell bar · matugen colors · liquidglass plugin · kitty terminal"
                                color: Colors.foreground; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                            }
                            Sep {}
                            Text { text: "Config paths"; color: Colors.surfaceForeground; font { pixelSize: 11; bold: true } }
                            Repeater {
                                model: [
                                    "~/Projects/DotFiles/Default/   — rice profile source",
                                    "~/.config/quickshell/           — bar (shell.qml, Colors.qml)",
                                    "~/.config/hypr/hyprland.lua     — Hyprland config",
                                    "~/.config/kitty/kitty.conf      — terminal",
                                    "~/.config/matugen/config.toml   — color templates",
                                    "~/Projects/DotFiles/recolor.sh  — ricemood recolor script",
                                ]
                                delegate: Text {
                                    required property string modelData
                                    text: modelData; color: Colors.surfaceForeground
                                    font { pixelSize: 11; family: "monospace" }
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Hdr { t: "Quick Actions"; i: "⚡" }
                        Card {
                            Flow { Layout.fillWidth: true; spacing: 8
                                ActionBtn {
                                    lbl: "Restart Quickshell"
                                    action: () => Quickshell.execDetached(["bash", "-c", "systemctl --user restart quickshell.service"])
                                }
                                ActionBtn {
                                    lbl: "Reload Hyprland"; col: Colors.secondary
                                    action: () => Quickshell.execDetached(["hyprctl", "reload"])
                                }
                                ActionBtn {
                                    lbl: "Run recolor.sh"; col: Colors.tertiary
                                    action: () => Quickshell.execDetached(["bash", "-c", "~/Projects/DotFiles/recolor.sh"])
                                }
                                ActionBtn {
                                    lbl: "Pick Wallpaper"; col: Colors.secondary
                                    action: () => Quickshell.execDetached(["waypaper"])
                                }
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ═══════════════════════════════════════════════════
                // PAGE 8 — Shortcuts
                // ═══════════════════════════════════════════════════
                ScrollView {
                    contentWidth: availableWidth; clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ColumnLayout {
                        width: parent.width - 32; x: 16; y: 16; spacing: 16

                        Hdr { t: "Apps & Windows"; i: "🪟" }
                        Card {
                            Repeater {
                                model: _appsData
                                delegate: RowLayout {
                                    id: _row
                                    property string _k:   modelData.k
                                    property string _lua: modelData.lua
                                    property string _val: modelData.k
                                    property string _cur: modelData.k
                                    property bool   _done: false
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        visible: !_row._lua
                                        implicitWidth: 160; implicitHeight: 24; radius: 5
                                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                        border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                                        Text { anchors.centerIn: parent; text: _row._k; color: Colors.primary; font { pixelSize: 11; family: "monospace" } }
                                    }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 190; implicitHeight: 28; radius: 5
                                        color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                        TextInput {
                                            id: _ti
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                            Component.onCompleted: { const s = root._overrides[_row._lua]; text = s || _row._k }
                                            onTextChanged: { _row._val = text; _row._done = false }
                                            Connections {
                                                target: root
                                                function onOverridesLoaded() {
                                                    const s = root._overrides[_row._lua]
                                                    if (s) _ti.text = s
                                                }
                                            }
                                        }
                                    }
                                    Text { text: modelData.d; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 46; implicitHeight: 28; radius: 6
                                        color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                                        border { color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45); width: 1 }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text { anchors.centerIn: parent; text: _row._done ? "✓" : "Set"; color: _row._done ? Colors.secondary : Colors.primary; font.pixelSize: 12 }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const nc = _row._val.trim(); const lua = _row._lua
                                                if (!nc || !lua) return
                                                // Previous combo: saved override or original default
                                                const prevCombo = root._overrides[lua] || _row._k
                                                // Update in-memory overrides
                                                const ov = Object.assign({}, root._overrides); ov[lua] = nc; root._overrides = ov
                                                // Unbind: old key for this action + all new override targets + default keys
                                                // (handles cross-session stale static binds and same-key conflicts)
                                                const unb = new Set([prevCombo])
                                                for (const [act, combo] of Object.entries(ov)) {
                                                    unb.add(combo)
                                                    const def = root._defaultKeys[act]; if (def) unb.add(def)
                                                }
                                                const parts = []
                                                for (const k of unb) parts.push("pcall(hl.unbind, '" + k + "')")
                                                for (const [act, combo] of Object.entries(ov)) parts.push("hl.bind('" + combo + "', " + act + ")")
                                                Quickshell.execDetached(["hyprctl", "eval", parts.join("; ")])
                                                Quickshell.execDetached(["python3", "-c",
                                                    "import json,sys,os; f,k,v=sys.argv[1],sys.argv[2],sys.argv[3]; d={}; " +
                                                    "(d.update(json.load(open(f)))) if os.path.exists(f) else None; " +
                                                    "d[k]=v; json.dump(d,open(f,'w'))",
                                                    "/home/sam/.config/quickshell/shortcut-overrides.json", lua, nc
                                                ])
                                                _row._cur = nc; _row._done = true
                                            }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: runtimeAppsModel
                                delegate: ShortcutRow { keys: model.sk; desc: model.sd }
                            }
                        }

                        Hdr { t: "Focus & Workspaces"; i: "🧭" }
                        Card {
                            Repeater {
                                model: _navData
                                delegate: RowLayout {
                                    id: _row
                                    property string _k:   modelData.k
                                    property string _lua: modelData.lua
                                    property string _val: modelData.k
                                    property string _cur: modelData.k
                                    property bool   _done: false
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        visible: !_row._lua
                                        implicitWidth: 160; implicitHeight: 24; radius: 5
                                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                        border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                                        Text { anchors.centerIn: parent; text: _row._k; color: Colors.primary; font { pixelSize: 11; family: "monospace" } }
                                    }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 190; implicitHeight: 28; radius: 5
                                        color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                        TextInput {
                                            id: _ti
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                            Component.onCompleted: { const s = root._overrides[_row._lua]; text = s || _row._k }
                                            onTextChanged: { _row._val = text; _row._done = false }
                                            Connections {
                                                target: root
                                                function onOverridesLoaded() {
                                                    const s = root._overrides[_row._lua]
                                                    if (s) _ti.text = s
                                                }
                                            }
                                        }
                                    }
                                    Text { text: modelData.d; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 46; implicitHeight: 28; radius: 6
                                        color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                                        border { color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45); width: 1 }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text { anchors.centerIn: parent; text: _row._done ? "✓" : "Set"; color: _row._done ? Colors.secondary : Colors.primary; font.pixelSize: 12 }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const nc = _row._val.trim(); const lua = _row._lua
                                                if (!nc || !lua) return
                                                // Previous combo: saved override or original default
                                                const prevCombo = root._overrides[lua] || _row._k
                                                // Update in-memory overrides
                                                const ov = Object.assign({}, root._overrides); ov[lua] = nc; root._overrides = ov
                                                // Unbind: old key for this action + all new override targets + default keys
                                                // (handles cross-session stale static binds and same-key conflicts)
                                                const unb = new Set([prevCombo])
                                                for (const [act, combo] of Object.entries(ov)) {
                                                    unb.add(combo)
                                                    const def = root._defaultKeys[act]; if (def) unb.add(def)
                                                }
                                                const parts = []
                                                for (const k of unb) parts.push("pcall(hl.unbind, '" + k + "')")
                                                for (const [act, combo] of Object.entries(ov)) parts.push("hl.bind('" + combo + "', " + act + ")")
                                                Quickshell.execDetached(["hyprctl", "eval", parts.join("; ")])
                                                Quickshell.execDetached(["python3", "-c",
                                                    "import json,sys,os; f,k,v=sys.argv[1],sys.argv[2],sys.argv[3]; d={}; " +
                                                    "(d.update(json.load(open(f)))) if os.path.exists(f) else None; " +
                                                    "d[k]=v; json.dump(d,open(f,'w'))",
                                                    "/home/sam/.config/quickshell/shortcut-overrides.json", lua, nc
                                                ])
                                                _row._cur = nc; _row._done = true
                                            }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: runtimeNavModel
                                delegate: ShortcutRow { keys: model.sk; desc: model.sd }
                            }
                        }

                        Hdr { t: "Move Windows"; i: "↔" }
                        Card {
                            Repeater {
                                model: _moveData
                                delegate: RowLayout {
                                    id: _row
                                    property string _k:   modelData.k
                                    property string _lua: modelData.lua
                                    property string _val: modelData.k
                                    property string _cur: modelData.k
                                    property bool   _done: false
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        visible: !_row._lua
                                        implicitWidth: 160; implicitHeight: 24; radius: 5
                                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                        border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                                        Text { anchors.centerIn: parent; text: _row._k; color: Colors.primary; font { pixelSize: 11; family: "monospace" } }
                                    }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 190; implicitHeight: 28; radius: 5
                                        color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                        TextInput {
                                            id: _ti
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                            Component.onCompleted: { const s = root._overrides[_row._lua]; text = s || _row._k }
                                            onTextChanged: { _row._val = text; _row._done = false }
                                            Connections {
                                                target: root
                                                function onOverridesLoaded() {
                                                    const s = root._overrides[_row._lua]
                                                    if (s) _ti.text = s
                                                }
                                            }
                                        }
                                    }
                                    Text { text: modelData.d; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 46; implicitHeight: 28; radius: 6
                                        color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                                        border { color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45); width: 1 }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text { anchors.centerIn: parent; text: _row._done ? "✓" : "Set"; color: _row._done ? Colors.secondary : Colors.primary; font.pixelSize: 12 }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const nc = _row._val.trim(); const lua = _row._lua
                                                if (!nc || !lua) return
                                                // Previous combo: saved override or original default
                                                const prevCombo = root._overrides[lua] || _row._k
                                                // Update in-memory overrides
                                                const ov = Object.assign({}, root._overrides); ov[lua] = nc; root._overrides = ov
                                                // Unbind: old key for this action + all new override targets + default keys
                                                // (handles cross-session stale static binds and same-key conflicts)
                                                const unb = new Set([prevCombo])
                                                for (const [act, combo] of Object.entries(ov)) {
                                                    unb.add(combo)
                                                    const def = root._defaultKeys[act]; if (def) unb.add(def)
                                                }
                                                const parts = []
                                                for (const k of unb) parts.push("pcall(hl.unbind, '" + k + "')")
                                                for (const [act, combo] of Object.entries(ov)) parts.push("hl.bind('" + combo + "', " + act + ")")
                                                Quickshell.execDetached(["hyprctl", "eval", parts.join("; ")])
                                                Quickshell.execDetached(["python3", "-c",
                                                    "import json,sys,os; f,k,v=sys.argv[1],sys.argv[2],sys.argv[3]; d={}; " +
                                                    "(d.update(json.load(open(f)))) if os.path.exists(f) else None; " +
                                                    "d[k]=v; json.dump(d,open(f,'w'))",
                                                    "/home/sam/.config/quickshell/shortcut-overrides.json", lua, nc
                                                ])
                                                _row._cur = nc; _row._done = true
                                            }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: runtimeMoveModel
                                delegate: ShortcutRow { keys: model.sk; desc: model.sd }
                            }
                        }

                        Hdr { t: "Screenshots & Tools"; i: "📷" }
                        Card {
                            Repeater {
                                model: _toolsData
                                delegate: RowLayout {
                                    id: _row
                                    property string _k:   modelData.k
                                    property string _lua: modelData.lua
                                    property string _val: modelData.k
                                    property string _cur: modelData.k
                                    property bool   _done: false
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        visible: !_row._lua
                                        implicitWidth: 160; implicitHeight: 24; radius: 5
                                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                        border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                                        Text { anchors.centerIn: parent; text: _row._k; color: Colors.primary; font { pixelSize: 11; family: "monospace" } }
                                    }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 190; implicitHeight: 28; radius: 5
                                        color: Qt.rgba(1,1,1,0.07); border { color: Qt.rgba(1,1,1,0.15); width: 1 }
                                        TextInput {
                                            id: _ti
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            color: Colors.foreground; font { pixelSize: 11; family: "monospace" }
                                            verticalAlignment: TextInput.AlignVCenter; selectByMouse: true
                                            Component.onCompleted: { const s = root._overrides[_row._lua]; text = s || _row._k }
                                            onTextChanged: { _row._val = text; _row._done = false }
                                            Connections {
                                                target: root
                                                function onOverridesLoaded() {
                                                    const s = root._overrides[_row._lua]
                                                    if (s) _ti.text = s
                                                }
                                            }
                                        }
                                    }
                                    Text { text: modelData.d; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Rectangle {
                                        visible: !!_row._lua
                                        implicitWidth: 46; implicitHeight: 28; radius: 6
                                        color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.18) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.08)
                                        border { color: _row._done ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.6) : Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.45); width: 1 }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text { anchors.centerIn: parent; text: _row._done ? "✓" : "Set"; color: _row._done ? Colors.secondary : Colors.primary; font.pixelSize: 12 }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const nc = _row._val.trim(); const lua = _row._lua
                                                if (!nc || !lua) return
                                                // Previous combo: saved override or original default
                                                const prevCombo = root._overrides[lua] || _row._k
                                                // Update in-memory overrides
                                                const ov = Object.assign({}, root._overrides); ov[lua] = nc; root._overrides = ov
                                                // Unbind: old key for this action + all new override targets + default keys
                                                // (handles cross-session stale static binds and same-key conflicts)
                                                const unb = new Set([prevCombo])
                                                for (const [act, combo] of Object.entries(ov)) {
                                                    unb.add(combo)
                                                    const def = root._defaultKeys[act]; if (def) unb.add(def)
                                                }
                                                const parts = []
                                                for (const k of unb) parts.push("pcall(hl.unbind, '" + k + "')")
                                                for (const [act, combo] of Object.entries(ov)) parts.push("hl.bind('" + combo + "', " + act + ")")
                                                Quickshell.execDetached(["hyprctl", "eval", parts.join("; ")])
                                                Quickshell.execDetached(["python3", "-c",
                                                    "import json,sys,os; f,k,v=sys.argv[1],sys.argv[2],sys.argv[3]; d={}; " +
                                                    "(d.update(json.load(open(f)))) if os.path.exists(f) else None; " +
                                                    "d[k]=v; json.dump(d,open(f,'w'))",
                                                    "/home/sam/.config/quickshell/shortcut-overrides.json", lua, nc
                                                ])
                                                _row._cur = nc; _row._done = true
                                            }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: runtimeToolsModel
                                delegate: ShortcutRow { keys: model.sk; desc: model.sd }
                            }
                        }

                        Hdr { t: "Media Keys"; i: "🎵" }
                        Card {
                            Repeater {
                                model: _mediaData
                                delegate: RowLayout {
                                    id: _row
                                    property string _k:   modelData.k
                                    property string _lua: modelData.lua
                                    Layout.fillWidth: true; spacing: 12
                                    Rectangle {
                                        implicitWidth: 160; implicitHeight: 24; radius: 5
                                        color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.12)
                                        border { color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.3); width: 1 }
                                        Text { anchors.centerIn: parent; text: _row._k; color: Colors.primary; font { pixelSize: 11; family: "monospace" } }
                                    }
                                    Text { text: modelData.d; color: Colors.foreground; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                }
                            }
                        }

                        Hdr { t: "Suggested / Unbound"; i: "➕" }
                        Text {
                            Layout.fillWidth: true
                            text: "Not currently bound. Edit the key combo, then click Set. Runtime only — add to hyprland.lua to persist across restarts."
                            color: Qt.rgba(Colors.tertiary.r, Colors.tertiary.g, Colors.tertiary.b, 0.8)
                            font.pixelSize: 10; wrapMode: Text.WordWrap
                        }
                        Card {
                            UnboundRow { desc: "Toggle fullscreen";             suggest: "SUPER + F";              luaAction: "hl.dsp.window.fullscreen()";                                        category: "apps" }
                            UnboundRow { desc: "Toggle maximize";               suggest: "SUPER + SHIFT + F";      luaAction: "hl.dsp.window.fullscreen({state=1})";                               category: "apps" }
                            UnboundRow { desc: "Pin window (all workspaces)";   suggest: "SUPER + Y";              luaAction: "hl.dsp.window.pin()";                                               category: "apps" }
                            UnboundRow { desc: "Center floating window";        suggest: "SUPER + CTRL + C";       luaAction: "hl.dsp.window.center()";                                            category: "apps" }
                            UnboundRow { desc: "Cycle next window";             suggest: "ALT + Tab";              luaAction: "hl.dsp.focus({window='next'})";                                     category: "nav" }
                            UnboundRow { desc: "Move window left (keyboard)";   suggest: "SUPER + SHIFT + left";   luaAction: "hl.dsp.window.move({direction='l'})";                               category: "move" }
                            UnboundRow { desc: "Move window right (keyboard)";  suggest: "SUPER + SHIFT + right";  luaAction: "hl.dsp.window.move({direction='r'})";                               category: "move" }
                            UnboundRow { desc: "Move window up (keyboard)";     suggest: "SUPER + SHIFT + up";     luaAction: "hl.dsp.window.move({direction='u'})";                               category: "move" }
                            UnboundRow { desc: "Move window down (keyboard)";   suggest: "SUPER + SHIFT + down";   luaAction: "hl.dsp.window.move({direction='d'})";                               category: "move" }
                            UnboundRow { desc: "Clipboard history (cliphist)";  suggest: "SUPER + CTRL + V";       luaAction: "hl.dsp.exec_cmd('cliphist list | rofi -dmenu | cliphist decode | wl-copy')"; category: "tools" }
                            UnboundRow { desc: "Screenshot to clipboard";       suggest: "CTRL + Print";           luaAction: "hl.dsp.exec_cmd('hyprshot -m region --clipboard-only')";            category: "tools" }
                            UnboundRow { desc: "Focus previous monitor";        suggest: "SUPER + CTRL + left";    luaAction: "hl.dsp.focus({monitor='-1'})";                                      category: "nav" }
                            UnboundRow { desc: "Focus next monitor";            suggest: "SUPER + CTRL + right";   luaAction: "hl.dsp.focus({monitor='+1'})";                                      category: "nav" }
                        }

                        Item { height: 8 }
                    }
                }

            } // StackLayout
        } // Content pane
    } // Main layout
}
