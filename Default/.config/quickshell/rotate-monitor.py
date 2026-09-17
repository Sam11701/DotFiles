#!/usr/bin/env python3
import re, json, subprocess, sys

CONFIG = "/home/sam/.config/hypr/hyprland.lua"
monitor_name = sys.argv[1]
direction = int(sys.argv[2])  # +1 CW, -1 CCW

# Get current monitor state from Hyprland
result = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True)
monitors = json.loads(result.stdout)

target = next((m for m in monitors if m['name'] == monitor_name), None)
if not target:
    sys.exit(f"Monitor {monitor_name} not found")

cur_t = target['transform']
lw, lh = target['width'], target['height']        # current logical dimensions
phys_w = lh if cur_t % 2 == 1 else lw            # physical width (undo transform)
phys_h = lw if cur_t % 2 == 1 else lh

new_t = (cur_t + direction) % 4
new_lw = phys_h if new_t % 2 == 1 else phys_w    # new logical width after rotation

# Find monitor directly to the right of target
right_mon = next(
    (m for m in monitors if m['x'] == target['x'] + lw and m['y'] == target['y']),
    None
)

def set_field(lines, output, field, value):
    """Set or insert a field in the hl.monitor block for the given output."""
    in_block = False
    found = False
    field_idx = None
    end_idx = None
    for i, line in enumerate(lines):
        if 'hl.monitor({' in line:
            in_block = True
            found = False
            field_idx = None
        elif in_block:
            if 'output' in line and f'"{output}"' in line:
                found = True
            if found and re.search(rf'\b{re.escape(field)}\b', line) and '=' in line:
                field_idx = i
            if line.strip() == '})':
                if found:
                    end_idx = i
                    break
                in_block = False
    if end_idx is None:
        return
    if field_idx is not None:
        lines[field_idx] = re.sub(rf'{re.escape(field)}\s*=\s*("[^"]*"|\d+)', f'{field} = {value}', lines[field_idx])
    else:
        lines.insert(end_idx, f'    {field} = {value},\n')

with open(CONFIG) as f:
    lines = f.readlines()

set_field(lines, monitor_name, 'transform', new_t)

if right_mon:
    new_x = target['x'] + new_lw
    set_field(lines, right_mon['name'], 'position', f'"{new_x}x{right_mon["y"]}"')

with open(CONFIG, 'w') as f:
    f.writelines(lines)

subprocess.run(['hyprctl', 'reload'])
