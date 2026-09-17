#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
WALLPAPER="${1:-}"
ACTIVE="$(cat "$DOTFILES_DIR/.active-rice" 2>/dev/null || true)"

if [[ -z "$ACTIVE" ]]; then
    echo "recolor: no active rice — run switch-rice.sh first" >&2
    exit 1
fi

if [[ -z "$WALLPAPER" ]]; then
    WALLPAPER="$(ls -t ~/.cache/wallpaper-picker/wallpaper_*.png 2>/dev/null | head -1 || true)"
fi

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    echo "recolor: no wallpaper found — pass a path or set one via waypaper" >&2
    exit 1
fi

TEMPLATES="$DOTFILES_DIR/$ACTIVE/ricemood"

if [[ ! -d "$TEMPLATES" ]]; then
    echo "recolor: no ricemood templates for profile '$ACTIVE'" >&2
    exit 1
fi

apply() {
    local src="$1" dst="$2"
    [[ -f "$src" ]] || return 0
    mkdir -p "$(dirname "$dst")"
    ricemood -i "$WALLPAPER" -f "$src" > "$dst"
    echo "  $(basename "$dst")"
}

echo "Recoloring '$ACTIVE' from $(basename "$WALLPAPER")..."

apply "$TEMPLATES/hypr/colors.lua"          "$HOME/.config/hypr/colors.lua"
apply "$TEMPLATES/quickshell/Colors.qml"    "$HOME/.config/quickshell/Colors.qml"
apply "$TEMPLATES/rofi/colors.rasi"         "$HOME/.config/rofi/colors.rasi"
apply "$TEMPLATES/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
apply "$TEMPLATES/waybar/style.css"         "$HOME/.config/waybar/style.css"

echo ""
echo "Reloading..."
hyprctl reload 2>/dev/null           && echo "  hyprland" || true
systemctl --user restart quickshell.service 2>/dev/null && echo "  quickshell" || true
pkill -SIGUSR1 kitty 2>/dev/null     && echo "  kitty" || true
pkill -SIGHUP waybar 2>/dev/null     && echo "  waybar" || true

echo "Done."
