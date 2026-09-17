#!/usr/bin/env python3
import json, os, subprocess, sys

overrides_file = os.path.expanduser("~/.config/quickshell/shortcut-overrides.json")
try:
    with open(overrides_file) as f:
        overrides = json.load(f)
except Exception:
    sys.exit(0)

if not overrides:
    sys.exit(0)

# Default combos for each action (mirrors settings.qml _defaultKeys / _appsData etc.)
defaults = {
    "hl.dsp.exec_cmd('kitty')":                                          "SUPER + Q",
    "hl.dsp.exec_cmd('brave')":                                          "SUPER + W",
    "hl.dsp.exec_cmd('nemo')":                                           "SUPER + E",
    "hl.dsp.exec_cmd('rofi -show drun')":                                "SUPER + R",
    "hl.dsp.window.close()":                                             "SUPER + C",
    "hl.dsp.window.float({action='toggle'})":                            "SUPER + V",
    "hl.dsp.window.pseudo()":                                            "SUPER + P",
    "hl.dsp.layout('togglesplit')":                                      "SUPER + J",
    "hl.dsp.workspace.toggle_special('magic')":                          "SUPER + S",
    "hl.dsp.window.move({workspace='special:magic'})":                   "SUPER + SHIFT + S",
    "hl.dsp.window.move({monitor='+1'})":                                "SUPER + ]",
    "hl.dsp.window.move({monitor='-1'})":                                "SUPER + [",
    "hl.dsp.workspace.move({monitor='+1'})":                             "SUPER + CTRL + ]",
    "hl.dsp.workspace.move({monitor='-1'})":                             "SUPER + CTRL + [",
    "hl.dsp.exec_cmd('hyprshot -m output -o /home/sam/Pictures')":       "Print",
    "hl.dsp.exec_cmd('hyprshot -m region -o /home/sam/Pictures')":       "SHIFT + Print",
    "hl.dsp.exec_cmd('hyprlock')":                                       "SUPER + L",
    "hl.dsp.exec_cmd('qs -p ~/.config/quickshell/settings.qml')":        "SUPER + I",
    "hl.dsp.exec_cmd('hyprpicker -a -n')":                               "SUPER + SHIFT + C",
    "hl.dsp.exec_cmd('kitty --class cava -e cava')":                     "SUPER + SHIFT + V",
    "hl.dsp.exec_cmd('wallpaper-picker')":                               "SUPER + SHIFT + W",
    "hl.dsp.exec_cmd('cursor-clip')":                                    "ALT+CTRL+SHIFT+V",
}

parts = []

# Unbind the default combo for each overridden action, and the new target combo
to_unbind = set()
for lua_action, new_combo in overrides.items():
    default = defaults.get(lua_action)
    if default:
        to_unbind.add(default)
    to_unbind.add(new_combo)

for combo in to_unbind:
    parts.append(f"pcall(hl.unbind, '{combo}')")

# Re-bind all overrides
for lua_action, new_combo in overrides.items():
    parts.append(f"hl.bind('{new_combo}', {lua_action})")

subprocess.run(["hyprctl", "eval", "; ".join(parts)])
