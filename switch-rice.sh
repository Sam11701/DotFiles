#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILES=("Default" "Direwolf")

usage() {
    echo "Usage: switch-rice <profile>"
    echo "Profiles: ${PROFILES[*]}"
    echo ""
    echo "Current: $(cat "$DOTFILES_DIR/.active-rice" 2>/dev/null || echo 'none')"
    exit 1
}

[[ $# -eq 1 ]] || usage

PROFILE="$1"
PROFILE_DIR="$DOTFILES_DIR/$PROFILE"

[[ -d "$PROFILE_DIR" ]] || { echo "Unknown profile: $PROFILE"; usage; }

echo "Switching to $PROFILE..."

# Back up current active configs that would be overwritten
backup_if_needed() {
    local src="$1" dst="$2"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "${dst}.bak-$(date +%Y%m%d%H%M%S)"
    fi
}

# Copy all .config/* entries from the profile
if [[ -d "$PROFILE_DIR/.config" ]]; then
    for entry in "$PROFILE_DIR/.config"/*/; do
        name="$(basename "$entry")"
        dst="$HOME/.config/$name"
        backup_if_needed "$entry" "$dst"
        rm -rf "$dst"
        cp -r "$entry" "$dst"
        echo "  .config/$name"
    done
fi

# Copy dotfiles from profile root (e.g. .Xresources)
for f in "$PROFILE_DIR"/.*; do
    name="$(basename "$f")"
    [[ "$name" == "." || "$name" == ".." || "$name" == ".config" ]] && continue
    dst="$HOME/$name"
    backup_if_needed "$f" "$dst"
    cp -r "$f" "$dst"
    echo "  ~/$name"
done

echo "$PROFILE" > "$DOTFILES_DIR/.active-rice"
echo ""
echo "Done. Active rice: $PROFILE"

case "$PROFILE" in
    Default)
        echo "Log out and start a Hyprland session to apply."
        ;;
    Direwolf)
        echo "Log out and start an i3 session to apply."
        echo "Make sure i3, polybar, dmenu, and ranger are installed:"
        echo "  sudo pacman -S i3-wm polybar dmenu ranger"
        ;;
esac
