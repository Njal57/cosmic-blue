#!/usr/bin/bash
# Default icon theme: "cosmic-blue", COSMIC's symbolic icons with Papirus-Dark
# applications, folders (blue, Papirus' default) and file types.
# Both themes come from the official Fedora repositories.
set -euox pipefail

dnf5 -y install papirus-icon-theme papirus-icon-theme-dark

python3 /ctx/build_files/icon_theme/compose.py
if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache --force /usr/share/icons/cosmic-blue
fi
