#!/bin/bash
# Usage: hypridle-set.sh <lock_secs> <dpms_secs> <sleep_secs>
# Pass 0 to disable that listener entirely.

python3 - "$1" "$2" "$3" << 'EOF'
import sys
lock, dpms, susp = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])

GENERAL = """general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}"""

parts = [GENERAL]
if lock: parts.append(f"""listener {{
    timeout = {lock}
    on-timeout = loginctl lock-session
}}""")
if dpms: parts.append(f"""listener {{
    timeout = {dpms}
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}}""")
if susp: parts.append(f"""listener {{
    timeout = {susp}
    on-timeout = systemctl suspend
}}""")

with open('/home/sam/.config/hypr/hypridle.conf', 'w') as f:
    f.write("\n\n".join(parts) + "\n")
EOF

systemctl --user restart hypridle
