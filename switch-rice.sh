#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILES=("Default")

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

backup_if_needed() {
    local src="$1" dst="$2"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "${dst}.bak-$(date +%Y%m%d%H%M%S)"
    fi
}

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
echo "Log out and start a Hyprland session to apply."
