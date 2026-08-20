#!/usr/bin/env bash
# Link this repo's configs into $HOME.
#
# Safe to re-run: anything already in place that is not already the correct
# symlink gets moved aside to <name>.bak first. Nothing is deleted.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PATHS=(
    .config/hypr
    .config/waybar
    .config/rofi
    .config/swaync
    .config/kitty
    .config/fastfetch
    .config/xdg-desktop-portal
    .config/brave-flags.conf
    .bashrc
    Pictures/Wallpapers
)

link() {
    local rel="$1"
    local src="$REPO/$rel"
    local dst="$HOME/$rel"

    [ -e "$src" ] || { printf '  skip   %s (not in repo)\n' "$rel"; return; }

    # Already pointing where it should.
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        printf '  ok     %s\n' "$rel"; return
    fi

    mkdir -p "$(dirname "$dst")"

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.bak"
        printf '  backup %s -> %s.bak\n' "$rel" "$rel"
    fi

    ln -s "$src" "$dst"
    printf '  link   %s\n' "$rel"
}

echo "Linking dotfiles from $REPO"
for p in "${PATHS[@]}"; do link "$p"; done

cat <<'EOF'

Done. To apply without logging out:

  hyprctl reload
  pkill waybar   && waybar &
  pkill hyprpaper && setsid hyprpaper >/dev/null 2>&1 </dev/null &
  pkill swaync   && swaync &

Verify the compositor config first with:

  Hyprland --verify-config
EOF
